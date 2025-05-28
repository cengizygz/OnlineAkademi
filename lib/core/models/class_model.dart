import 'package:cloud_firestore/cloud_firestore.dart';

class ClassModel {
  final String id;
  final String name;
  final String teacherId;
  final List<String> studentIds;
  final String description;
  final Timestamp createdAt;

  ClassModel({
    required this.id,
    required this.name,
    required this.teacherId,
    required this.studentIds,
    this.description = '',
    required this.createdAt,
  });

  // From Firestore
  factory ClassModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClassModel(
      id: doc.id,
      name: data['name'] ?? '',
      teacherId: data['teacherId'] ?? '',
      studentIds: List<String>.from(data['studentIds'] ?? []),
      description: data['description'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  // To Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'teacherId': teacherId,
      'studentIds': studentIds,
      'description': description,
      'createdAt': createdAt,
    };
  }

  // Create a copy with changes
  ClassModel copyWith({
    String? id,
    String? name,
    String? teacherId,
    List<String>? studentIds,
    String? description,
    Timestamp? createdAt,
  }) {
    return ClassModel(
      id: id ?? this.id,
      name: name ?? this.name,
      teacherId: teacherId ?? this.teacherId,
      studentIds: studentIds ?? this.studentIds,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 