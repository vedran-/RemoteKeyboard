/// Domain Layer - Core business logic
///
/// This layer contains the heart of the application:
/// - Entities: Objects with identity (Command, Device, Connection)
/// - Value Objects: Immutable objects (MouseButton, MediaAction, DeviceStatus)
/// - Domain Services: Business logic interfaces
///
/// The domain layer has NO dependencies on Flutter or external libraries.

export 'entities/command.dart';
export 'entities/device.dart';
export 'entities/connection.dart';
