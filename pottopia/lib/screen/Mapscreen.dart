import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MapScreen extends StatefulWidget {
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentLatLng;
  Marker? _selectedMarker;
  String? _permissionMessage;
  final TextEditingController _searchController = TextEditingController();

  // Google Geocoding API 키를 여기에 입력하세요
  final String _googleApiKey = 'AIzaSyCj5L0Mtj7nA8z_4g3CX2DGt51EFSqkF0s';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 주소 검색 및 이동 함수
  Future<void> _searchAddress(String address) async {
    if (address.isEmpty) return;

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=$address&key=$_googleApiKey&language=ko');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['results'].isNotEmpty) {
        final location = data['results'][0]['geometry']['location'];
        final lat = location['lat'];
        final lng = location['lng'];
        final target = LatLng(lat, lng);

        setState(() {
          _selectedMarker = Marker(
            markerId: MarkerId('selected'),
            position: target,
          );
        });

        _moveCamera(target);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('주소를 찾을 수 없습니다.')),
        );
      }
    }
  }

  // 기존 함수들 (_getCurrentLocation, _setFallbackLocation, _moveCamera, _onMapTap, _getAddressFromLatLng)은 그대로 사용

  // ... (기존 코드, initState, _getCurrentLocation, _setFallbackLocation, _moveCamera, _onMapTap, _getAddressFromLatLng)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('위치 선택')),
      body: _currentLatLng == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  if (_permissionMessage != null)
                    Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        _permissionMessage!,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            )
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLatLng!,
                    zoom: 14,
                  ),
                  myLocationEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _moveCamera(_currentLatLng!);
                  },
                  markers: _selectedMarker != null ? {_selectedMarker!} : {},
                  onTap: _onMapTap,
                ),
                // 검색창 추가
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '주소 또는 장소명을 입력하세요',
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: Icon(Icons.search),
                          onPressed: () => _searchAddress(_searchController.text),
                        ),
                      ),
                      onSubmitted: (value) => _searchAddress(value),
                    ),
                  ),
                ),
                if (_permissionMessage != null)
                  Positioned(
                    top: 76, // 검색창 아래로 이동
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _permissionMessage!,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: _selectedMarker == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                if (_selectedMarker != null) {
                  final lat = _selectedMarker!.position.latitude;
                  final lng = _selectedMarker!.position.longitude;
                  final address = await _getAddressFromLatLng(lat, lng);
                  if (address != null) {
                    Navigator.pop(context, {
                      'address': address,
                      'lat': lat,
                      'lng': lng,
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('주소를 가져오지 못했습니다.')),
                    );
                  }
                }
              },
              label: Text('이 위치로 설정'),
              icon: Icon(Icons.check),
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // 기존 함수들 복사 (아래는 예시, 실제 코드에 맞게 넣으세요)
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _setFallbackLocation('위치 서비스가 꺼져 있습니다.');
      return;
    }

    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _setFallbackLocation('위치 권한이 거부되었습니다. 서울로 이동합니다.');
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      LatLng currentLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLatLng = currentLatLng;
        _selectedMarker = Marker(
          markerId: MarkerId('selected'),
          position: currentLatLng,
        );
        _permissionMessage = null;
      });

      _moveCamera(currentLatLng);
    } catch (e) {
      _setFallbackLocation('위치를 가져올 수 없습니다. 서울로 이동합니다.');
    }
  }

  void _setFallbackLocation(String message) {
    LatLng fallbackLatLng = LatLng(37.5665, 126.9780); // 서울
    setState(() {
      _currentLatLng = fallbackLatLng;
      _selectedMarker = Marker(
        markerId: MarkerId('selected'),
        position: fallbackLatLng,
      );
      _permissionMessage = message;
    });

    _moveCamera(fallbackLatLng);
  }

  void _moveCamera(LatLng target) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(target),
      );
    }
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _selectedMarker = Marker(
        markerId: MarkerId('selected'),
        position: position,
      );
    });
  }

  Future<String?> _getAddressFromLatLng(double lat, double lng) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleApiKey&language=ko');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['results'].isNotEmpty) {
        String fullAddress = data['results'][0]['formatted_address'];
        if (fullAddress.startsWith('대한민국 ')) {
          fullAddress = fullAddress.replaceFirst('대한민국 ', '');
        }
        return fullAddress;
      }
    }
    return null;
  }
}
