import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLogoutRequested extends AuthEvent {}

class AuthPhoneLoginRequested extends AuthEvent {
  final String phoneNumber;

  const AuthPhoneLoginRequested(this.phoneNumber);

  @override
  List<Object?> get props => [phoneNumber];
}

class AuthGoogleLoginRequested extends AuthEvent {}

class AuthLoginSuccess extends AuthEvent {
  final User user;

  const AuthLoginSuccess(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthTermsAccepted extends AuthEvent {
  final bool accepted;

  const AuthTermsAccepted(this.accepted);

  @override
  List<Object?> get props => [accepted];
}
