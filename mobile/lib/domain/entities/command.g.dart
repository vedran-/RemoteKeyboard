// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:json_annotation/json_annotation.dart';

part of 'command.dart';

T _$enumDecode<T>(Map<String, dynamic> json, T Function(String) enumValues) {
  final value = json as String;
  return enumValues(value);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Command _$CommandFromJson(Map<String, dynamic> json) => Command(
      type: $enumDecode(_$CommandTypeEnumMap, json['type']),
      payload: json['payload'],
    );

Map<String, dynamic> _$CommandToJson(Command instance) => <String, dynamic>{
      'type': _$CommandTypeEnumMap[instance.type]!,
      'payload': instance.payload,
    };

const _$CommandTypeEnumMap = {
  CommandType.mouse: 'mouse',
  CommandType.keyboard: 'keyboard',
  CommandType.media: 'media',
  CommandType.custom: 'custom',
};

MouseMovePayload _$MouseMovePayloadFromJson(Map<String, dynamic> json) =>
    MouseMovePayload(
      dx: (json['dx'] as num).toInt(),
      dy: (json['dy'] as num).toInt(),
    );

Map<String, dynamic> _$MouseMovePayloadToJson(MouseMovePayload instance) =>
    <String, dynamic>{
      'dx': instance.dx,
      'dy': instance.dy,
    };

MouseClickPayload _$MouseClickPayloadFromJson(Map<String, dynamic> json) =>
    MouseClickPayload(
      button: $enumDecode(_$MouseButtonEnumMap, json['button']),
      state: $enumDecode(_$ButtonStateEnumMap, json['state']),
    );

Map<String, dynamic> _$MouseClickPayloadToJson(MouseClickPayload instance) =>
    <String, dynamic>{
      'button': _$MouseButtonEnumMap[instance.button]!,
      'state': _$ButtonStateEnumMap[instance.state]!,
    };

const _$MouseButtonEnumMap = {
  MouseButton.left: 'left',
  MouseButton.right: 'right',
  MouseButton.middle: 'middle',
};

const _$ButtonStateEnumMap = {
  ButtonState.press: 'press',
  ButtonState.release: 'release',
};

MouseScrollPayload _$MouseScrollPayloadFromJson(Map<String, dynamic> json) =>
    MouseScrollPayload(
      dx: (json['dx'] as num).toInt(),
      dy: (json['dy'] as num).toInt(),
    );

Map<String, dynamic> _$MouseScrollPayloadToJson(MouseScrollPayload instance) =>
    <String, dynamic>{
      'dx': instance.dx,
      'dy': instance.dy,
    };

KeyPressPayload _$KeyPressPayloadFromJson(Map<String, dynamic> json) =>
    KeyPressPayload(
      key: json['key'] as String,
    );

Map<String, dynamic> _$KeyPressPayloadToJson(KeyPressPayload instance) =>
    <String, dynamic>{
      'key': instance.key,
    };

TypeTextPayload _$TypeTextPayloadFromJson(Map<String, dynamic> json) =>
    TypeTextPayload(
      text: json['text'] as String,
    );

Map<String, dynamic> _$TypeTextPayloadToJson(TypeTextPayload instance) =>
    <String, dynamic>{
      'text': instance.text,
    };

MediaPayload _$MediaPayloadFromJson(Map<String, dynamic> json) => MediaPayload(
      action: $enumDecode(_$MediaActionEnumMap, json['action']),
    );

Map<String, dynamic> _$MediaPayloadToJson(MediaPayload instance) =>
    <String, dynamic>{
      'action': _$MediaActionEnumMap[instance.action]!,
    };

const _$MediaActionEnumMap = {
  MediaAction.playPause: 'playPause',
  MediaAction.nextTrack: 'nextTrack',
  MediaAction.prevTrack: 'prevTrack',
  MediaAction.volumeUp: 'volumeUp',
  MediaAction.volumeDown: 'volumeDown',
  MediaAction.mute: 'mute',
};
