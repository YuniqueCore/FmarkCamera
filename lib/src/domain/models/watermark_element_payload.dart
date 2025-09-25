class WatermarkElementPayload {
  const WatermarkElementPayload({
    this.text,
    this.imagePath,
    this.assetName,
    this.imageBytesBase64,
    this.timeFormat,
    this.showAddress = true,
    this.showCoordinates = false,
    this.showWeatherDescription = true,
  });

  final String? text;
  final String? imagePath;
  final String? assetName;
  final String? imageBytesBase64;
  final String? timeFormat;
  final bool showAddress;
  final bool showCoordinates;
  final bool showWeatherDescription;

  WatermarkElementPayload copyWith({
    String? text,
    String? imagePath,
    String? assetName,
    String? imageBytesBase64,
    String? timeFormat,
    bool? showAddress,
    bool? showCoordinates,
    bool? showWeatherDescription,
  }) {
    return WatermarkElementPayload(
      text: text ?? this.text,
      imagePath: imagePath ?? this.imagePath,
      assetName: assetName ?? this.assetName,
      imageBytesBase64: imageBytesBase64 ?? this.imageBytesBase64,
      timeFormat: timeFormat ?? this.timeFormat,
      showAddress: showAddress ?? this.showAddress,
      showCoordinates: showCoordinates ?? this.showCoordinates,
      showWeatherDescription:
          showWeatherDescription ?? this.showWeatherDescription,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'text': text,
        'imagePath': imagePath,
        'assetName': assetName,
        'imageBytesBase64': imageBytesBase64,
        'timeFormat': timeFormat,
        'showAddress': showAddress,
        'showCoordinates': showCoordinates,
        'showWeatherDescription': showWeatherDescription,
      };

  factory WatermarkElementPayload.fromJson(Map<String, dynamic> json) {
    return WatermarkElementPayload(
      text: json['text'] as String?,
      imagePath: json['imagePath'] as String?,
      assetName: json['assetName'] as String?,
      imageBytesBase64: json['imageBytesBase64'] as String?,
      timeFormat: json['timeFormat'] as String?,
      showAddress: json['showAddress'] as bool? ?? true,
      showCoordinates: json['showCoordinates'] as bool? ?? false,
      showWeatherDescription: json['showWeatherDescription'] as bool? ?? true,
    );
  }
}
