import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PantallaFacturas extends StatefulWidget {
  const PantallaFacturas({super.key});

  @override
  State<PantallaFacturas> createState() => _PantallaFacturasState();
}

class _PantallaFacturasState extends State<PantallaFacturas> {
  bool _cargando = false;
  List<dynamic> _productosLeidos = [];
  String _mensaje = "";

  // Función mágica para elegir el XML y enviarlo al Backend
  Future<void> _subirFactura() async {
    // 1. Abrir el buscador de archivos (Solo permitimos .xml)
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xml'],
    );

    if (result != null) {
      setState(() {
        _cargando = true;
        _mensaje = "Enviando factura a Pingu POS...";
        _productosLeidos = [];
      });

      try {
        // 2. Preparar el archivo para enviarlo por HTTP
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('http://localhost:8080/api/facturas/subir'),
        );

        // Como estamos en Chrome (Web), usamos los "bytes" del archivo
        request.files.add(http.MultipartFile.fromBytes(
          'archivo',
          result.files.first.bytes!,
          filename: result.files.first.name,
        ));

        // 3. Enviar al Backend de Java
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          // ¡Éxito! Java nos devolvió la lista de productos
          setState(() {
            _productosLeidos = json.decode(utf8.decode(response.bodyBytes));
            _mensaje = "¡Factura procesada con éxito! 🐧";
            _cargando = false;
          });
        } else {
          setState(() {
            _mensaje = "Error del servidor: ${response.body}";
            _cargando = false;
          });
        }
      } catch (e) {
        setState(() {
          _mensaje = "Error de conexión: ¿Está encendido el Backend?";
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingreso de Facturas (XML)'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _cargando ? null : _subirFactura,
              icon: const Icon(Icons.upload_file, size: 30),
              label: const Text('Subir Factura XML del SII', style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
            const SizedBox(height: 20),
            Text(_mensaje, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // Si está cargando, mostramos un circulito
            if (_cargando) const CircularProgressIndicator(),

            // 🌟 AQUÍ ESTÁ LA LISTA INTELIGENTE 🌟
            Expanded(
              child: ListView.builder(
                itemCount: _productosLeidos.length,
                itemBuilder: (context, index) {
                  var item = _productosLeidos[index];
                  
                  // Verificamos si Pingu lo conoce o no (viene desde Java)
                  bool esConocido = item['estado'] == 'CONOCIDO';

                  return Card(
                    elevation: 2,
                    // Si es conocido el fondo es verde clarito, si no, naranjo clarito
                    color: esConocido ? Colors.green.shade50 : Colors.orange.shade50,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ListTile(
                        leading: Icon(
                          esConocido ? Icons.check_circle : Icons.warning_amber_rounded, 
                          color: esConocido ? Colors.green : Colors.orange,
                          size: 40,
                        ),
                        title: Text(item['nombreItemProveedor'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 5),
                            Text("Cantidad: ${item['cantidadComprada']}  |  Costo Neto: \$${item['precioCostoNeto']}"),
                            const SizedBox(height: 5),
                            // Mostramos el SKU o una advertencia
                            Text(
                              esConocido ? "✅ Asociado al SKU: ${item['skuAsociado']}" : "⚠️ Pingu no conoce este producto",
                              style: TextStyle(
                                color: esConocido ? Colors.green.shade700 : Colors.red,
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ],
                        ),
                        trailing: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: esConocido ? Colors.green : Colors.orange,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          ),
                          icon: Icon(esConocido ? Icons.update : Icons.link, color: Colors.white),
                          label: Text(
                            esConocido ? "Actualizar Stock" : "Enseñar a Pingu", 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                          ),
                          onPressed: () {
                            if (esConocido) {
                              // Aquí irá la función para sumar el stock y actualizar precios
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Pronto: Actualizando stock en BD...')),
                              );
                            } else {
                              // Aquí abriremos el buscador para mapear el producto
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Pronto: Abriendo buscador de inventario...')),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}