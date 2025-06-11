// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hotkey_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HotkeyConfigAdapter extends TypeAdapter<HotkeyConfig> {
  @override
  final int typeId = 2;

  @override
  HotkeyConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HotkeyConfig(
      keyCode: fields[0] as String,
      modifiers: (fields[1] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, HotkeyConfig obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.keyCode)
      ..writeByte(1)
      ..write(obj.modifiers);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HotkeyConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
