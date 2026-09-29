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

/// Supabase confirmó el envío del SMS con el código; la UI puede arrancar el
/// cooldown de reenvío. (No significa que el código sea correcto — eso lo
/// determina el siguiente verifyOTP, ver [OtpVerified]).
class AuthOtpSent extends AuthState {
  final String phone;

  const AuthOtpSent(this.phone);

  @override
  List<Object?> get props => [phone];
}

class AuthNeedsRegistration extends AuthState {
  final String phone;
  final String prefilledEmail;

  const AuthNeedsRegistration(this.phone, {this.prefilledEmail = ''});

  @override
  List<Object?> get props => [phone, prefilledEmail];
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
