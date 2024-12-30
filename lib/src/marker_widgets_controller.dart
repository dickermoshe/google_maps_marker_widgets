import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'location_puck.dart';
import 'marker_widget.dart';

///Manages [MarkerWidget]s and associated [Marker]s on a [GoogleMap].
///
class MarkerWidgetsController extends ChangeNotifier {
  double pixelRatio = 1.0;
  final Map<MarkerId, MarkerWidget> _markerWidgets = {};
  final Map<MarkerId, Marker> _markers = {};
  final Map<MarkerId, AnimationController> _markerAnimationControllers = {};

  GoogleMapController? googleMapController;
  CameraPosition? cameraPosition;

  ///Set of [Marker]s to display on [GoogleMap].
  ValueNotifier<Set<Marker>> markers = ValueNotifier<Set<Marker>>({});

  ///[MarkerWidget]s currently being displayed and tracked.
  List<MarkerWidget> markerWidgets() {
    return _markerWidgets.values.toList();
  }

  ///Callback for setting the [googleMapController].
  void onMapCreated(GoogleMapController controller) {
    googleMapController = controller;
  }

  ///Callback for updating the [cameraPosition].
  void onCameraMove(CameraPosition newCameraPosition) {
    cameraPosition = newCameraPosition;
  }

  void addDeviceMarker(
      {LatLng initialPosition = const LatLng(0, 0),
      LocationPuck locationPuck = const LocationPuck()}) {
    final markerId = MarkerId('device');
    final deviceMarker = Marker(
        markerId: markerId,
        position: initialPosition,
        anchor: Offset(0.5, 0.5));
    addMarkerWidget(
        markerWidget: MarkerWidget(
          markerId: markerId,
          child: locationPuck,
        ),
        marker: deviceMarker);
  }

  ///Adds a [Marker] and associated [MarkerWidget] to the [GoogleMap].
  ///
  ///*Note* [markerWidget] and [marker] should have the same [MarkerId]!
  void addMarkerWidget(
      {required MarkerWidget markerWidget, required Marker marker}) async {
    final markerId = marker.markerId;
    assert(!_markerWidgets.containsKey(markerId),
        'Marker $markerId already exists! Use updateMarkerWidget indstead.');
    assert(markerWidget.markerId == marker.markerId,
        'MarkerWidget and Marker do not have the same MarkerId!');
    _markerWidgets[markerId] = markerWidget;
    _markers[markerId] = marker;
    final newSet = <Marker>{};
    newSet.addAll(_markers.values);
    markers.value = newSet;
    notifyListeners();
  }

  ///Returns the [Marker] associated with [markerId].
  Marker? markerForId(MarkerId markerId) {
    return _markers[markerId];
  }

  ///Adds the [animationController] used for updating marker positions on the GoogleMap to this
  ///controller.
  ///
  ///This method is called by [MarkerWidget] on the first build and shouldn't be
  ///called directly.
  void addMarkerUpdateAnimationContoller(
      AnimationController animationController, MarkerId markerId) {
    _markerAnimationControllers[markerId] = animationController;
  }

  ///Update the [bitmapDescriptor] for the [Marker] with [markerId].
  void updateMarkerImage(
      {required BitmapDescriptor? bitmapDescriptor,
      required MarkerId markerId}) {
    assert(_markers.containsKey(markerId), 'Marker $markerId not found!');
    final oldMarker = _markers[markerId]!;
    final newMarker = oldMarker.copyWith(iconParam: bitmapDescriptor);
    _markers[markerId] = newMarker;
    final newSet = <Marker>{};
    newSet.addAll(_markers.values);
    markers.value = newSet;
  }

  ///Updates a [marker] on [GoogleMap].
  ///
  ///By default changes in latitude and longitude will be [animated] using a default [duration] of
  ///1000 millisecons.
  void updateMarker(Marker marker,
      {bool animated = true,
      Curve curve = Curves.easeInOutCubic,
      Duration duration = const Duration(milliseconds: 1000)}) async {
    assert(_markers.containsKey(marker.markerId),
        'Marker ${marker.markerId.toString()} not found!');
    final markerId = marker.markerId;
    final oldMarker = _markers[markerId]!;
    final oldLatLang = oldMarker.position;
    final newLatLang = marker.position;

    if (animated) {
      final animationController = _markerAnimationControllers[marker.markerId]!;
      animationController.duration = duration;
      final animation = animationController.drive(CurveTween(curve: curve));
      animation.addListener(() async {
        if (animationController.isAnimating) {
          //update latitude and longitude
          final double latStep =
              (newLatLang.latitude - oldLatLang.latitude) * animation.value +
                  oldLatLang.latitude;
          final double lngStep =
              (newLatLang.longitude - oldLatLang.longitude) * animation.value +
                  oldLatLang.longitude;
          final latlangStep = LatLng(latStep, lngStep);

          final markerStep =
              _markers[markerId]!.copyWith(positionParam: latlangStep);
          _markers[markerId] = markerStep;
          final newSet = <Marker>{};
          newSet.addAll(_markers.values
              .where((setMarker) => setMarker.markerId != marker.markerId));
          newSet.add(markerStep);
          markers.value = newSet;
        }
        if (animationController.isCompleted) {
          _markers[markerId] =
              _markers[markerId]!.copyWith(positionParam: marker.position);
        }
      });
      await animationController.forward();
      animationController.reset();
    } else {
      _markers[markerId] = marker;
      final newSet = <Marker>{};
      newSet.addAll(_markers.values);
      markers.value = newSet;
    }
  }
}
