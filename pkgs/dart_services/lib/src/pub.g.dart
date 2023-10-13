// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pub.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PackageConfig _$PackageConfigFromJson(Map<String, dynamic> json) =>
    PackageConfig(
      configVersion: json['configVersion'] as int,
      packages: (json['packages'] as List<dynamic>)
          .map((e) => PackageInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      fromCached: json['fromCached'] as bool,
    );

Map<String, dynamic> _$PackageConfigToJson(PackageConfig instance) =>
    <String, dynamic>{
      'configVersion': instance.configVersion,
      'packages': instance.packages,
      'fromCached': instance.fromCached,
    };

PackageInfo _$PackageInfoFromJson(Map<String, dynamic> json) => PackageInfo(
      name: json['name'] as String,
      languageVersion: json['languageVersion'] as String,
      version: json['version'] as String?,
      flutterSdkPath: json['flutterSdkPath'] as String?,
    );

Map<String, dynamic> _$PackageInfoToJson(PackageInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'languageVersion': instance.languageVersion,
      'version': instance.version,
      'flutterSdkPath': instance.flutterSdkPath,
    };
