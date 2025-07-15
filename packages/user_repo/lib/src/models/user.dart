import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.documentId,
    this.firstName,
    this.lastName,
    this.email,
    this.profilePic,
  });

  final String id;
  final String documentId;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? profilePic;

  @override
  List<Object?> get props =>
      [id, documentId, firstName, lastName, email, profilePic];

  static const empty = User(id: '-', documentId: '-');

  factory User.fromJson(Map<String, dynamic> json) {
    // Strapi can return profilePic as null or as an object with a url
    final profilePicData = json['profilePic'];
    final profilePicUrl = profilePicData is Map ? profilePicData['url'] : null;

    return User(
      id: json['id'].toString(),
      documentId: json['documentId'] ?? json['id'].toString(), // Fallback for documentId
      firstName: json['firstName'],
      lastName: json['lastName'],
      email: json['email'],
      profilePic: profilePicUrl,
    );
  }
}
