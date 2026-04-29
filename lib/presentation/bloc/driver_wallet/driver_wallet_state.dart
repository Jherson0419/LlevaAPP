import 'package:equatable/equatable.dart';

class DriverWalletState extends Equatable {
  const DriverWalletState({
    this.owedBalance = 0,
    this.isLoading = false,
  });

  final double owedBalance;
  final bool isLoading;

  DriverWalletState copyWith({
    double? owedBalance,
    bool? isLoading,
  }) {
    return DriverWalletState(
      owedBalance: owedBalance ?? this.owedBalance,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [owedBalance, isLoading];
}
