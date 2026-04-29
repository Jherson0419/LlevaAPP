import 'package:equatable/equatable.dart';

import '../../../domain/entities/user.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Subida de documentos de conductor antes de crear el perfil ([completed]/[total]).
class AuthUploadingDriverDocs extends AuthState {
  final int completed;
  final int total;

  const AuthUploadingDriverDocs({
    required this.completed,
    required this.total,
  });

  double get progress => total <= 0 ? 0 : completed / total;

  @override
  List<Object?> get props => [completed, total];
}

class AuthAuthenticated extends AuthState {
  final UserEntity user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthNeedsRegistration extends AuthState {
  final String phone;

  const AuthNeedsRegistration(this.phone);

  @override
  List<Object?> get props => [phone];
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

