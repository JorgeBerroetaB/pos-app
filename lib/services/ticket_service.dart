import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/detalle_venta.dart';

class TicketService {
  Future<void> imprimirTicket({
    required List<DetalleVenta> carrito,
    required double total,
    required int totalAproximado,
    required String metodoPago,
  }) async {
    final doc = pw.Document();

    // 1. Descargamos las fuentes compatibles con español (Unicode)
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(15),
        // 2. Le decimos a la página que use estas fuentes por defecto
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text('MI LOCAL GOD', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text('Dirección de tu local 123'),
              pw.Text('Tel: +56 9 1234 5678'),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Text('TICKET DE VENTA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Fecha: ${DateTime.now().toString().substring(0, 16)}'),
              pw.Divider(),
              
              // Encabezados de productos
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(flex: 2, child: pw.Text('CANT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 5, child: pw.Text('DESCRIPCIÓN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 3, child: pw.Text('SUBTOTAL', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.SizedBox(height: 5),

              // Lista de productos
              ...carrito.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(flex: 2, child: pw.Text('${item.cantidad}')),
                      pw.Expanded(flex: 5, child: pw.Text(item.producto.nombre)),
                      pw.Expanded(flex: 3, child: pw.Text('\$${item.subtotal.toStringAsFixed(0)}', textAlign: pw.TextAlign.right)),
                    ],
                  ),
                );
              }).toList(),

              pw.Divider(),
              
              // Totales
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text('\$$totalAproximado', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Pago con:'),
                  pw.Text(metodoPago.toUpperCase()),
                ],
              ),
              
              pw.SizedBox(height: 20),
              pw.Text('¡Gracias por su compra!', textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 10),
              pw.Text('***', textAlign: pw.TextAlign.center),
            ],
          );
        },
      ),
    );

    // Manda a imprimir directamente usando el diálogo del sistema
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Ticket_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}