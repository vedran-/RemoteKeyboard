// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Device _$DeviceFromJson(Map<String, dynamic> json) => Device(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      port: (json['port'] as num).toInt(),
      path: json['path'] as String,
      version: json['version'] as String,
      status: $enumDecode(_$DeviceStatusEnumMap, json['status']),
      lastSeen: json['lastSeen'] == null
          ? null
          : DateTime.parse(json['lastSeen'] as String),
    );

Map<String, dynamic> _$DeviceToJson(Device instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'address': instance.address,
      'port': instance.port,
      'path': instance.path,
      'version': instance.version,
      'status': _$DeviceStatusEnumMap[instance.status]!,
      'lastSeen': instance.lastSeen?.toIso8601String(),
    };

const _$DeviceStatusEnumMap = {
  DeviceStatus.available: 'available',
  DeviceStatus.connecting: 'connecting',
  DeviceStatus.connected: 'connected',
  DeviceStatus.unavailable: 'unavailable',
};
