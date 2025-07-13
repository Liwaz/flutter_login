import 'package:equatable/equatable.dart';

/// For simplicity, a user just has an id property but in practice 
/// we will most certainlty have additional properties like 
/// firstName, lastName, avatarUrl, etc…

class User extends Equatable {
  const User(this.id);

  final String id;

  @override
  List<Object> get props => [id];

  static const empty = User('-');
}