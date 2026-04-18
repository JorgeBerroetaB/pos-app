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
  List<dynamic> _resultadosBusqueda = [];
  String _mensaje = "";
  final String _baseUrl = 'http://localhost:8080/api';

  // 1. Función para subir el XML
  Future<void> _subirFactura() async {
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
        var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/facturas/subir'));
        request.files.add(http.MultipartFile.fromBytes(
          'archivo',
          result.files.first.bytes!,
          filename: result.files.first.name,
        ));

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          setState(() {
            _productosLeidos = json.decode(utf8.decode(response.bodyBytes));
            _mensaje = "¡Factura procesada con éxito! 🐧";
            _cargando = false;
          });
        } else {
          _mostrarError("Error del servidor: ${response.body}");
        }
      } catch (e) {
        _mostrarError("Error de conexión: ¿Está encendido el Backend?");
      }
    }
  }

  // 2. Función para "Enseñar a Pingu" (Buscar en inventario)
  void _abrirBuscadorMapeo(Map<String, dynamic> itemFactura) {
    _resultadosBusqueda = [];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text("Asociar: ${itemFactura['nombreItemProveedor']}"),
          content: SizedBox(
            width: 500,
            height: 400,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: "Buscar en inventario (Nombre o SKU)",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) async {
                    if (value.length > 2) {
                      final resp = await http.get(Uri.parse('$_baseUrl/productos/buscar?termino=$value'));
                      if (resp.statusCode == 200) {
                        setModalState(() {
                          _resultadosBusqueda = json.decode(utf8.decode(resp.bodyBytes));
                        });
                      }
                    }
                  },
                ),
                const Divider(),
                Expanded(
                  child: _resultadosBusqueda.isEmpty 
                    ? const Center(child: Text("Escribe para buscar..."))
                    : ListView.builder(
                        itemCount: _resultadosBusqueda.length,
                        itemBuilder: (context, i) {
                          var prod = _resultadosBusqueda[i];
                          return ListTile(
                            title: Text(prod['nombre']),
                            subtitle: Text("SKU: ${prod['sku']} | Precio actual: \$${prod['precioVenta']}"),
                            trailing: const Icon(Icons.add_link, color: Colors.blue),
                            onTap: () {
                              Navigator.pop(context); // 1. Cierra la ventana de búsqueda
                              // 2. Guarda el conocimiento y luego abre la ventana de margen
                              _guardarMapeoYActualizar(itemFactura, prod['sku']); 
                            },
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ],
        ),
      ),
    );
  }

  // 3. Función para guardar relación en el diccionario
  Future<void> _guardarMapeoYActualizar(Map<String, dynamic> item, String skuLocal) async {
    try {
      final responseDic = await http.post(
        Uri.parse('$_baseUrl/diccionario/aprender'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "rutProveedor": item['rutProveedor'],
          "nombreItemProveedor": item['nombreItemProveedor'],
          "skuInterno": skuLocal
        }),
      );

      if (responseDic.statusCode == 200) {
        // Pingu ya aprendió. Ahora abrimos la ventana de margen para sumar el stock y el precio final
        _pedirMargenYActualizar(skuLocal, item['precioCostoNeto'], item['cantidadComprada']);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🐧 Pingu ha aprendido este producto.'), backgroundColor: Colors.blue)
        );
      }
    } catch (e) {
      _mostrarError("Error al guardar el conocimiento.");
    }
  }

  // 4. VENTANA PARA PREGUNTAR EL MARGEN DE GANANCIA
  Future<void> _pedirMargenYActualizar(String sku, double costoNeto, double cantidad) async {
    double costoConIva = costoNeto * 1.19; 
    TextEditingController margenController = TextEditingController(text: "30"); // 30% por defecto

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Configurar Precio 🐧", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Costo Neto: \$${costoNeto.toStringAsFixed(0)}", style: const TextStyle(fontSize: 16)),
            Text("Costo con IVA (19%): \$${costoConIva.toStringAsFixed(0)}", 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 16)),
            const SizedBox(height: 20),
            TextField(
              controller: margenController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "¿Qué % de ganancia deseas?",
                suffixText: "%",
                border: OutlineInputBorder(),
                filled: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              double margen = double.tryParse(margenController.text) ?? 0.0;
              Navigator.pop(context); // Cierra la ventana del margen
              _enviarActualizacionAlBackend(sku, costoNeto, cantidad, margen); // Llama a Java
            },
            child: const Text("Guardar Precio y Stock", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // 5. FUNCIÓN QUE ENVÍA LOS DATOS FINALES A JAVA
  Future<void> _enviarActualizacionAlBackend(String sku, double costo, double cantidad, double margen) async {
    try {
      final resp = await http.put(
        Uri.parse('$_baseUrl/productos/$sku/actualizar-desde-factura?costo=$costo&cantidad=$cantidad&margen=$margen'),
      );

      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Stock y precio actualizados para el SKU: $sku'), backgroundColor: Colors.green),
        );
      } else {
        _mostrarError("Error al actualizar stock del SKU: $sku");
      }
    } catch (e) {
      _mostrarError("Error de conexión al actualizar producto.");
    }
  }

  void _mostrarError(String msg) {
    setState(() {
      _mensaje = msg;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingreso de Facturas (XML)', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _cargando ? null : _subirFactura,
              icon: const Icon(Icons.upload_file, size: 30),
              label: const Text('Subir Factura XML del SII', style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
            ),
            const SizedBox(height: 20),
            Text(_mensaje, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (_cargando) const CircularProgressIndicator(),
            Expanded(
              child: ListView.builder(
                itemCount: _productosLeidos.length,
                itemBuilder: (context, index) {
                  var item = _productosLeidos[index];
                  bool esConocido = item['estado'] == 'CONOCIDO';
                  return Card(
                    color: esConocido ? Colors.green.shade50 : Colors.orange.shade50,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: Icon(
                        esConocido ? Icons.check_circle : Icons.warning_amber_rounded, 
                        color: esConocido ? Colors.green : Colors.orange,
                        size: 40,
                      ),
                      title: Text(item['nombreItemProveedor'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Cant: ${item['cantidadComprada']} | Costo Neto: \$${item['precioCostoNeto']}\n${esConocido ? "✅ SKU: ${item['skuAsociado']}" : "⚠️ Pingu no conoce este producto"}"),
                      trailing: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: esConocido ? Colors.green : Colors.orange),
                        icon: Icon(esConocido ? Icons.refresh : Icons.school, color: Colors.white),
                        label: Text(esConocido ? "Actualizar" : "Enseñar", style: const TextStyle(color: Colors.white)),
                        onPressed: () {
                          if (esConocido) {
                            // Si es conocido, vamos directo a preguntar el margen
                            _pedirMargenYActualizar(item['skuAsociado'], item['precioCostoNeto'], item['cantidadComprada']);
                          } else {
                            // Si es desconocido, abrimos buscador
                            _abrirBuscadorMapeo(item);
                          }
                        },
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