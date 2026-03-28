enum MetodoPago {
  tarjeta,
  efectivo,
  transferencia,
  abono
}

// Ayuda para mostrar el nombre bonito en la interfaz
extension MetodoPagoExtension on MetodoPago {
  String get nombre {
    switch (this) {
      case MetodoPago.tarjeta: return 'Tarjeta';
      case MetodoPago.efectivo: return 'Efectivo';
      case MetodoPago.transferencia: return 'Transferencia';
      case MetodoPago.abono: return 'Abono';
    }
  }
}