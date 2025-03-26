import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:share_plus/share_plus.dart'; // Using share_plus

class ComplaintPage extends StatefulWidget {
  final Position? currentPosition;

  const ComplaintPage({Key? key, this.currentPosition}) : super(key: key);

  @override
  _ComplaintPageState createState() => _ComplaintPageState();
}

class _ComplaintPageState extends State<ComplaintPage> {
  final TextEditingController _descriptionController = TextEditingController();
  File? _imageFile;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();
  String _address = "Fetching address...";
  bool _isLoading = false;
  bool _isSubmitting = false;
  Position? _position;
  String? _photoStatus;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    setState(() {
      _isLoading = true;
      _address = "Getting your location...";
    });

    try {
      if (widget.currentPosition != null) {
        _position = widget.currentPosition;
        await _getAddressFromLatLng();
      } else {
        await _fetchCurrentLocation();
      }
    } catch (e) {
      print("Error initializing location: $e");
      setState(() {
        _isLoading = false;
        _address = "Failed to get location. Tap to retry";
      });
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _address = "Location services are disabled. Please enable them.";
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _address = "Location permission denied. Please allow access.";
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _address = "Location permission permanently denied. Enable in settings.";
          _isLoading = false;
        });
        return;
      }

      _position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      print("Location fetched: ${_position!.latitude}, ${_position!.longitude}");
      await _getAddressFromLatLng();
    } catch (e) {
      print("Error fetching location: $e");
      setState(() {
        _isLoading = false;
        _address = "Failed to get location: $e. Tap to retry";
      });
    }
  }

  Future<void> _getAddressFromLatLng() async {
    if (_position == null) {
      setState(() {
        _isLoading = false;
        _address = "No location data available";
      });
      return;
    }

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _position!.latitude,
        _position!.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _address =
          "${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.postalCode ?? ''}, ${place.country ?? ''}";
          _address = _address.replaceAll(RegExp(r', ,'), ',').trim();
          _address = _address.replaceAll(RegExp(r',,'), ',').trim();
          _address = _address.replaceAll(RegExp(r'^,|,$'), '').trim();
          if (_address.isEmpty) {
            _address = "Address not found at ${_position!.latitude}, ${_position!.longitude}";
          }
        });
      } else {
        setState(() {
          _address = "No address found for ${_position!.latitude}, ${_position!.longitude}";
        });
      }
    } catch (e) {
      print("Error getting address: $e");
      setState(() {
        _address = "Failed to get address: $e. Coordinates: ${_position!.latitude}, ${_position!.longitude}";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showImageSourceOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (photo != null) {
      setState(() {
        if (kIsWeb) {
          photo.readAsBytes().then((bytes) {
            setState(() {
              _imageBytes = bytes;
              _photoStatus = "Photo captured from camera";
            });
          });
        } else {
          _imageFile = File(photo.path);
          _photoStatus = "Photo captured from camera";
        }
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        if (kIsWeb) {
          image.readAsBytes().then((bytes) {
            setState(() {
              _imageBytes = bytes;
              _photoStatus = "Photo uploaded from gallery";
            });
          });
        } else {
          _imageFile = File(image.path);
          _photoStatus = "Photo uploaded from gallery";
        }
      });
    }
  }

  Future<void> _submitComplaint() async {
    if (_imageFile == null && _imageBytes == null) {
      _showErrorSnackBar("Please provide an image");
      return;
    }

    if (_descriptionController.text.isEmpty) {
      _showErrorSnackBar("Please describe the issue");
      return;
    }

    if (_position == null) {
      _showErrorSnackBar("Location data is not available");
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Simulate submission delay
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      // Get current timestamp
      String timestamp = DateTime.now().toString();

      // Create Google Maps link
      String googleMapsLink =
          "https://www.google.com/maps?q=${_position!.latitude},${_position!.longitude}";

      // Prepare the shareable content
      String complaintDetails = """
Complaint Details:
Description: ${_descriptionController.text}
Location: $_address
Coordinates: ${_position!.latitude}, ${_position!.longitude}
Google Maps Link: $googleMapsLink
Timestamp: $timestamp
""";

      // Share the complaint details along with the image (if available)
      if (kIsWeb && _imageBytes != null) {
        // For web, share text only (file sharing depends on browser support)
        await Share.share(
          complaintDetails,
          subject: 'Complaint Submission',
        );
      } else if (_imageFile != null) {
        // For mobile, share text and image using shareFiles
        await Share.shareXFiles(
          [XFile(_imageFile!.path)], // Updated to use XFile for share_plus
          text: complaintDetails,
          subject: 'Complaint Submission',
        );
      } else {
        // Fallback to text-only sharing
        await Share.share(
          complaintDetails,
          subject: 'Complaint Submission',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Complaint submitted and shared successfully"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      print("Error submitting complaint: $e");
      if (!mounted) return;
      _showErrorSnackBar("Failed to submit complaint: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F9D58),
        title: const Text("File a Complaint"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Photo Evidence",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Center(
              child: InkWell(
                onTap: _showImageSourceOptions,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: (_imageFile == null && _imageBytes == null)
                      ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate,
                          size: 50, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text("Tap to add a photo",
                          style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text("(Take a photo or choose from gallery)",
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 12)),
                    ],
                  )
                      : Stack(
                    fit: StackFit.expand,
                    children: [
                      if (kIsWeb && _imageBytes != null)
                        Image.memory(_imageBytes!, fit: BoxFit.cover)
                      else if (!kIsWeb && _imageFile != null)
                        Image.file(_imageFile!, fit: BoxFit.cover),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _imageFile = null;
                              _imageBytes = null;
                              _photoStatus = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _photoStatus ?? "",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: InkWell(
                          onTap: _showImageSourceOptions,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text("Change Photo",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text("Description",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                hintText: "Describe the issue in detail",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            const Text("Location",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _isLoading ? null : _fetchCurrentLocation,
              child: Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isLoading
                    ? const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF0F9D58)),
                      ),
                      SizedBox(height: 8),
                      Text("Getting location..."),
                    ],
                  ),
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Color(0xFF0F9D58)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_address,
                              style: const TextStyle(fontSize: 16)),
                        ),
                        if (_position == null)
                          const Icon(Icons.refresh,
                              color: Color(0xFF0F9D58)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_position != null)
                      Text(
                        "Coordinates: ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}",
                        style:
                        TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F9D58),
                ),
                onPressed: _isSubmitting ? null : _submitComplaint,
                child: _isSubmitting
                    ? const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                )
                    : const Text("SUBMIT COMPLAINT",
                    style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}