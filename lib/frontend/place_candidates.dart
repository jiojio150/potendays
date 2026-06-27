// lib/frontend/place_candidates.dart

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// 장소 후보 입력 / 투표 — REQ-F-06, F-07
class PlaceCandidatesScreen extends StatefulWidget {
  final String meetingId;
  final String meetingTitle;
  final String meetingEmoji;

  const PlaceCandidatesScreen({
    super.key,
    required this.meetingId,
    this.meetingTitle = '종강 파티',
    this.meetingEmoji = '🎉',
  });

  @override
  State<PlaceCandidatesScreen> createState() => _PlaceCandidatesScreenState();
}

class _PlaceCandidatesScreenState extends State<PlaceCandidatesScreen> {
  static const MethodChannel _configChannel = MethodChannel('potendays/config');
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(37.5665, 126.9780),
    zoom: 12.5,
  );

  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  final TextEditingController _searchController = TextEditingController();
  List<_PlaceSearchResult> _searchResults = <_PlaceSearchResult>[];

  bool _isAdding = false;
  bool _isVoting = false;
  bool _isSearching = false;
  String? _searchError;

  String? get _currentUid {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  CollectionReference<Map<String, dynamic>> get _candidateCollection {
    return FirebaseFirestore.instance
        .collection('meetings')
        .doc(widget.meetingId)
        .collection('placeCandidates');
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _selectLocation(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
  }

  Future<void> _showAddPlaceDialog() async {
    if (_currentUid == null) {
      _showMessage('로그인이 필요합니다.');
      return;
    }

    if (_selectedLocation == null) {
      _showMessage('지도에서 추가할 장소의 위치를 길게 눌러주세요.');
      return;
    }

    final selectedLocation = _selectedLocation!;

    final result = await showDialog<_PlaceInputResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _PlaceInputDialog(selectedLocation: selectedLocation);
      },
    );

    if (result == null) {
      return;
    }

    await _addPlace(
      name: result.name,
      address: result.address,
      location: selectedLocation,
    );
  }

  Future<String> _resolveGoogleMapsApiKey() async {
    final String envKey =
        dotenv.env['GOOGLE_MAPS_API_KEY']?.trim().isNotEmpty == true
        ? dotenv.env['GOOGLE_MAPS_API_KEY']!.trim()
        : (dotenv.env['MAPS_API_KEY']?.trim() ?? '');

    if (envKey.isNotEmpty) {
      return envKey;
    }

    if (!Platform.isAndroid) {
      return '';
    }

    try {
      return await _configChannel.invokeMethod<String>('googleMapsApiKey') ??
          '';
    } catch (error) {
      debugPrint('Google Maps API key 조회 실패: $error');
      return '';
    }
  }

  Future<void> _searchPlaces() async {
    final String query = _searchController.text.trim();

    if (query.isEmpty) {
      _showMessage('검색할 장소명을 입력해 주세요.');
      return;
    }

    final String apiKey = await _resolveGoogleMapsApiKey();

    if (apiKey.isEmpty) {
      setState(() {
        _searchResults = <_PlaceSearchResult>[];
        _searchError = '.env에 GOOGLE_MAPS_API_KEY를 추가하면 장소 검색을 사용할 수 있습니다.';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    final HttpClient client = HttpClient();

    try {
      final Uri uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/textsearch/json',
        <String, String>{
          'query': query,
          'key': apiKey,
          'language': 'ko',
          'region': 'kr',
        },
      );

      final HttpClientRequest request = await client.getUrl(uri);
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> json =
          jsonDecode(body) as Map<String, dynamic>;
      final String status = json['status'] as String? ?? 'UNKNOWN';

      if (status != 'OK' && status != 'ZERO_RESULTS') {
        throw StateError(json['error_message'] as String? ?? status);
      }

      final List<dynamic> results =
          json['results'] as List<dynamic>? ?? <dynamic>[];

      if (!mounted) return;

      setState(() {
        _searchResults = results
            .take(5)
            .map((item) {
              final Map<String, dynamic> raw = item as Map<String, dynamic>;
              final Map<String, dynamic> geometry =
                  raw['geometry'] as Map<String, dynamic>? ??
                  <String, dynamic>{};
              final Map<String, dynamic> location =
                  geometry['location'] as Map<String, dynamic>? ??
                  <String, dynamic>{};
              final double? lat = (location['lat'] as num?)?.toDouble();
              final double? lng = (location['lng'] as num?)?.toDouble();

              if (lat == null || lng == null) {
                return null;
              }

              return _PlaceSearchResult(
                name: raw['name'] as String? ?? '이름 없는 장소',
                address: raw['formatted_address'] as String? ?? '주소 정보 없음',
                location: LatLng(lat, lng),
                rating: (raw['rating'] as num?)?.toDouble(),
              );
            })
            .whereType<_PlaceSearchResult>()
            .toList();
        _searchError = _searchResults.isEmpty ? '검색 결과가 없습니다.' : null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _searchResults = <_PlaceSearchResult>[];
        _searchError = '장소 검색에 실패했습니다. $error';
      });
    } finally {
      client.close(force: true);

      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _addSearchResult(_PlaceSearchResult place) async {
    if (_currentUid == null) {
      _showMessage('로그인이 필요합니다.');
      return;
    }

    setState(() {
      _selectedLocation = place.location;
    });

    await _moveCamera(place.location);

    if (!mounted) return;

    final result = await showDialog<_PlaceInputResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _PlaceInputDialog(
          selectedLocation: place.location,
          initialName: place.name,
          initialAddress: place.address,
        );
      },
    );

    if (result == null) {
      return;
    }

    await _addPlace(
      name: result.name,
      address: result.address,
      location: place.location,
    );
  }

  Future<void> _addPlace({
    required String name,
    required String address,
    required LatLng location,
  }) async {
    final uid = _currentUid;

    if (uid == null) {
      _showMessage('로그인이 필요합니다.');
      return;
    }

    setState(() {
      _isAdding = true;
    });

    try {
      await _candidateCollection.add({
        'name': name,
        'address': address,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'createdByUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'voterUids': <String>[],
      });

      if (!mounted) return;

      setState(() {
        _selectedLocation = null;
      });

      _showMessage('$name 장소가 추가되었습니다.');
    } on FirebaseException catch (e) {
      debugPrint('장소 추가 Firebase 오류: ${e.code} / ${e.message}');

      if (!mounted) return;

      _showMessage('장소 추가에 실패했습니다. (${e.code})');
    } catch (e) {
      debugPrint('장소 추가 오류: $e');

      if (!mounted) return;

      _showMessage('장소 추가에 실패했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  Future<void> _vote({
    required String selectedPlaceId,
    required String selectedPlaceName,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs,
  }) async {
    final uid = _currentUid;

    if (uid == null) {
      _showMessage('로그인이 필요합니다.');
      return;
    }

    if (_isVoting) {
      return;
    }

    setState(() {
      _isVoting = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      bool alreadyVotedSelectedPlace = false;

      for (final doc in allDocs) {
        final voterUids = List<String>.from(
          doc.data()['voterUids'] ?? <String>[],
        );

        if (doc.id == selectedPlaceId) {
          alreadyVotedSelectedPlace = voterUids.contains(uid);
        }
      }

      for (final doc in allDocs) {
        final voterUids = List<String>.from(
          doc.data()['voterUids'] ?? <String>[],
        );

        if (doc.id == selectedPlaceId && alreadyVotedSelectedPlace) {
          if (voterUids.contains(uid)) {
            batch.update(doc.reference, {
              'voterUids': FieldValue.arrayRemove([uid]),
            });
          }

          continue;
        }

        if (doc.id == selectedPlaceId) {
          if (!voterUids.contains(uid)) {
            batch.update(doc.reference, {
              'voterUids': FieldValue.arrayUnion([uid]),
            });
          }
        } else {
          if (voterUids.contains(uid)) {
            batch.update(doc.reference, {
              'voterUids': FieldValue.arrayRemove([uid]),
            });
          }
        }
      }

      await batch.commit();

      if (!mounted) return;

      if (alreadyVotedSelectedPlace) {
        _showMessage('$selectedPlaceName 투표를 취소했습니다.');
      } else {
        _showMessage('$selectedPlaceName에 투표했습니다.');
      }
    } on FirebaseException catch (e) {
      debugPrint('장소 투표 Firebase 오류: ${e.code} / ${e.message}');

      if (!mounted) return;

      _showMessage('투표에 실패했습니다. (${e.code})');
    } catch (e) {
      debugPrint('장소 투표 오류: $e');

      if (!mounted) return;

      _showMessage('투표에 실패했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _isVoting = false;
        });
      }
    }
  }

  Future<void> _moveCamera(LatLng location) async {
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: 16),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  LatLng? _readLocation(Map<String, dynamic> data) {
    final latitude = data['latitude'];
    final longitude = data['longitude'];

    if (latitude is! num || longitude is! num) {
      return null;
    }

    return LatLng(latitude.toDouble(), longitude.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.meetingId.isEmpty || widget.meetingId == 'default_id') {
      return Scaffold(
        backgroundColor: const Color(0xFF1C1C1E),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      '실제 모임 상세 화면에서 장소 후보를 열어주세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _candidateCollection
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          '장소 후보를 불러오지 못했습니다.\n'
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs =
                      snapshot.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                  final Set<Marker> markers = {};

                  for (final doc in docs) {
                    final data = doc.data();
                    final location = _readLocation(data);

                    if (location == null) {
                      continue;
                    }

                    markers.add(
                      Marker(
                        markerId: MarkerId(doc.id),
                        position: location,
                        infoWindow: InfoWindow(
                          title: data['name']?.toString() ?? '장소',
                          snippet: data['address']?.toString() ?? '',
                        ),
                        onTap: () {
                          _moveCamera(location);
                        },
                      ),
                    );
                  }

                  if (_selectedLocation != null) {
                    markers.add(
                      Marker(
                        markerId: const MarkerId('new-place'),
                        position: _selectedLocation!,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueAzure,
                        ),
                        infoWindow: const InfoWindow(
                          title: '새 장소 위치',
                          snippet: '추가 버튼을 눌러 정보를 입력하세요.',
                        ),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.meetingEmoji} '
                          '${widget.meetingTitle}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '지도를 길게 눌러 새 장소의 위치를 지정하세요.',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        _buildPlaceSearch(),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: double.infinity,
                            height: 240,
                            child: GoogleMap(
                              initialCameraPosition: _initialCameraPosition,
                              markers: markers,
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: false,
                              mapToolbarEnabled: false,
                              compassEnabled: true,
                              onMapCreated: (controller) {
                                _mapController = controller;
                              },
                              onLongPress: _selectLocation,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        _buildRecommendedPlace(docs),
                        if (docs.isNotEmpty) const SizedBox(height: 22),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '후보 장소 목록',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              '${docs.length}개',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (docs.isEmpty)
                          _buildEmptyState()
                        else
                          ...docs.map((doc) {
                            final data = doc.data();

                            final voterUids = List<String>.from(
                              data['voterUids'] ?? <String>[],
                            );

                            final uid = _currentUid;

                            final isVoted =
                                uid != null && voterUids.contains(uid);

                            final location = _readLocation(data);

                            final name = data['name']?.toString() ?? '이름 없는 장소';

                            final address =
                                data['address']?.toString() ?? '주소 없음';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _PlaceCard(
                                name: name,
                                address: address,
                                voteCount: voterUids.length,
                                isVoted: isVoted,
                                isVoting: _isVoting,
                                onCardTap: location == null
                                    ? null
                                    : () {
                                        _moveCamera(location);
                                      },
                                onVote: () {
                                  _vote(
                                    selectedPlaceId: doc.id,
                                    selectedPlaceName: name,
                                    allDocs: docs,
                                  );
                                },
                              ),
                            );
                          }),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceSearch() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchPlaces(),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '장소명 검색',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF9FC2FF),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1C1C1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _isSearching ? null : _searchPlaces,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4A6CF7),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _isSearching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('검색', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
          if (_searchError != null) ...[
            const SizedBox(height: 10),
            Text(
              _searchError!,
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
            ),
          ],
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._searchResults.map(
              (place) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PlaceSearchResultTile(
                  place: place,
                  onPreview: () async {
                    setState(() {
                      _selectedLocation = place.location;
                    });
                    await _moveCamera(place.location);
                  },
                  onAdd: () => _addSearchResult(place),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendedPlace(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs)
      ..sort((a, b) {
        final int aVotes = List<String>.from(
          a.data()['voterUids'] ?? <String>[],
        ).length;
        final int bVotes = List<String>.from(
          b.data()['voterUids'] ?? <String>[],
        ).length;
        return bVotes.compareTo(aVotes);
      });

    final best = sorted.first;
    final data = best.data();
    final location = _readLocation(data);
    final int voteCount = List<String>.from(
      data['voterUids'] ?? <String>[],
    ).length;

    return _RecommendedPlaceCard(
      name: data['name']?.toString() ?? '이름 없는 장소',
      address: data['address']?.toString() ?? '주소 없음',
      voteCount: voteCount,
      onTap: location == null ? null : () => _moveCamera(location),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 12, 20, 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF3A3A3C), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const Expanded(
            child: Text(
              '장소 후보',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _isAdding ? null : _showAddPlaceDialog,
            icon: _isAdding
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add, size: 16, color: Colors.white),
            label: Text(
              _isAdding ? '추가 중' : '추가',
              style: const TextStyle(color: Colors.white),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.add_location_alt_outlined,
            color: Colors.white38,
            size: 46,
          ),
          SizedBox(height: 12),
          Text(
            '등록된 장소 후보가 없습니다.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '지도에서 위치를 지정한 뒤\n추가 버튼을 눌러주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final String name;
  final String address;
  final int voteCount;
  final bool isVoted;
  final bool isVoting;
  final VoidCallback? onCardTap;
  final VoidCallback onVote;

  const _PlaceCard({
    required this.name,
    required this.address,
    required this.voteCount,
    required this.isVoted,
    required this.isVoting,
    required this.onCardTap,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF242424),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onCardTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isVoted ? const Color(0xFF4A6CF7) : Colors.transparent,
              width: 1.3,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      address,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: isVoting ? null : onVote,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isVoted
                            ? const Color(0xFF294C7A)
                            : Colors.transparent,
                        side: BorderSide(
                          color: isVoted
                              ? const Color(0xFF4A6CF7)
                              : Colors.white24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        isVoted ? '투표 취소' : '투표하기',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$voteCount\n표',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF4AA3FF),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceSearchResult {
  final String name;
  final String address;
  final LatLng location;
  final double? rating;

  const _PlaceSearchResult({
    required this.name,
    required this.address,
    required this.location,
    this.rating,
  });
}

class _PlaceSearchResultTile extends StatelessWidget {
  final _PlaceSearchResult place;
  final VoidCallback onPreview;
  final VoidCallback onAdd;

  const _PlaceSearchResultTile({
    required this.place,
    required this.onPreview,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.place_rounded, color: Color(0xFF9FC2FF)),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPreview,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      place.address,
                      if (place.rating != null) '평점 ${place.rating}',
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: '후보 추가',
            onPressed: onAdd,
            icon: const Icon(
              Icons.add_location_alt_rounded,
              color: Color(0xFF9FC2FF),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendedPlaceCard extends StatelessWidget {
  final String name;
  final String address;
  final int voteCount;
  final VoidCallback? onTap;

  const _RecommendedPlaceCard({
    required this.name,
    required this.address,
    required this.voteCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF28345F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF4A6CF7)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.recommend_rounded,
              color: Color(0xFF9FC2FF),
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '추천 장소',
                    style: TextStyle(
                      color: Color(0xFF9FC2FF),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$voteCount표',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceInputResult {
  final String name;
  final String address;

  const _PlaceInputResult({required this.name, required this.address});
}

class _PlaceInputDialog extends StatefulWidget {
  final LatLng selectedLocation;
  final String initialName;
  final String initialAddress;

  const _PlaceInputDialog({
    required this.selectedLocation,
    this.initialName = '',
    this.initialAddress = '',
  });

  @override
  State<_PlaceInputDialog> createState() => _PlaceInputDialogState();
}

class _PlaceInputDialogState extends State<_PlaceInputDialog> {
  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _addressController = TextEditingController();

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName;
    _addressController.text = widget.initialAddress;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _errorMessage = '장소명을 입력해주세요.';
      });
      return;
    }

    if (address.isEmpty) {
      setState(() {
        _errorMessage = '주소를 입력해주세요.';
      });
      return;
    }

    Navigator.pop(context, _PlaceInputResult(name: name, address: address));
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white30),
      filled: true,
      fillColor: const Color(0xFF1C1C1E),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF4A6CF7), width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2C2C2E),
      title: const Text(
        '장소 후보 추가',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(label: '장소명', hint: '예: 강남 파스타집'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _addressController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                _submit();
              },
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                label: '주소',
                hint: '예: 서울 강남구 역삼동 123',
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '선택 좌표\n'
                '${widget.selectedLocation.latitude.toStringAsFixed(6)}, '
                '${widget.selectedLocation.longitude.toStringAsFixed(6)}',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('취소', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A6CF7),
          ),
          child: const Text('추가', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
