import 'package:flutter/material.dart';
import 'models/producto.dart';
import 'services/api_service.dart';
import 'pantalla_caja.dart'; 
import 'pantalla_corte_caja.dart'; 

void main() {
  runApp(const YupiPosApp());
}

class YupiPosApp extends StatelessWidget {
  const YupiPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yupi POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const PantallaInventario(),
    );
  }
}

class PantallaInventario extends StatefulWidget {
  const PantallaInventario({super.key});

  @override
  State<PantallaInventario> createState() => _PantallaInventarioState();
}

class _PantallaInventarioState extends State<PantallaInventario> {
  final ApiService apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  Future<List<Producto>>? _productosFuture;

  @override
  void initState() {
    super.initState();
    _cargarTodosLosProductos();
  }

  void _cargarTodosLosProductos() {
    setState(() {
      _productosFuture = apiService.obtenerTodos();
    });
  }

  void _buscarProducto() {
    String termino = _searchController.text.trim();
    if (termino.isEmpty) {
      _cargarTodosLosProductos();
      return;
    }
    setState(() {
      _productosFuture = apiService.buscarProductos(termino);
    });
  }

  void _eliminar(String sku) async {
    try {
      await apiService.eliminarProducto(sku);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto eliminado 🗑️'), backgroundColor: Colors.redAccent),
        );
      }
      _cargarTodosLosProductos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // --- FUNCIÓN PARA MOSTRAR EL FORMULARIO (CREAR O EDITAR) ---
  void _mostrarFormulario({Producto? productoExistente}) {
    final bool esEdicion = productoExistente != null;
    
    // Controladores para los campos de texto
    final skuController = TextEditingController(text: productoExistente?.sku ?? '');
    final nombreController = TextEditingController(text: productoExistente?.nombre ?? '');
    final precioVentaController = TextEditingController(text: productoExistente?.precioVenta.toString() ?? '');
    final precioCostoController = TextEditingController(text: productoExistente?.precioCosto.toString() ?? '');
    final stockController = TextEditingController(text: productoExistente?.stock.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(esEdicion ? 'Editar Producto ✏️' : 'Nuevo Producto 📦'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: skuController,
                  decoration: const InputDecoration(labelText: 'Código de Barras (SKU)'),
                  enabled: !esEdicion, // No dejamos cambiar el SKU si estamos editando
                ),
                TextField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre del Producto')),
                TextField(controller: precioVentaController, decoration: const InputDecoration(labelText: 'Precio de Venta (\$)'), keyboardType: TextInputType.number),
                TextField(controller: precioCostoController, decoration: const InputDecoration(labelText: 'Precio de Costo (\$)'), keyboardType: TextInputType.number),
                TextField(controller: stockController, decoration: const InputDecoration(labelText: 'Unidades en Stock'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Cierra la ventana
              child: const Text('Cancelar', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                // Armamos el objeto con los datos del formulario
                final nuevoProducto = Producto(
                  sku: skuController.text.trim(),
                  nombre: nombreController.text.trim(),
                  precioVenta: double.tryParse(precioVentaController.text) ?? 0.0,
                  precioCosto: double.tryParse(precioCostoController.text) ?? 0.0,
                  stock: int.tryParse(stockController.text) ?? 0,
                );

                try {
                  if (esEdicion) {
                    await apiService.actualizarProducto(nuevoProducto.sku, nuevoProducto);
                  } else {
                    await apiService.crearProducto(nuevoProducto);
                  }
                  
                  if (mounted) {
                    Navigator.pop(context); // Cerramos el formulario
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(esEdicion ? 'Producto actualizado ✅' : 'Producto creado ✅'), backgroundColor: Colors.green),
                    );
                    _cargarTodosLosProductos(); // Recargamos la lista
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pingu POS 🐧', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blueAccent,
        actions: [
          // --- ¡NUEVO! BOTÓN PARA IR AL CORTE DE CAJA ---
          IconButton(
            icon: const Icon(Icons.analytics, color: Colors.white, size: 30),
            tooltip: 'Corte de Caja',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PantallaCorteCaja()),
              );
            },
          ),
          // Botón existente de la Caja Registradora
          IconButton(
            icon: const Icon(Icons.point_of_sale, color: Colors.white, size: 30),
            tooltip: 'Ir a la Caja',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PantallaCaja()),
              ).then((_) => _cargarTodosLosProductos()); 
            },
          ),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _cargarTodosLosProductos),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Producto'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o SKU...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onSubmitted: (_) => _buscarProducto(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _buscarProducto,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20)),
                  child: const Text('Buscar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Producto>>(
              future: _productosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No hay productos.'));

                final productos = snapshot.data!;
                return ListView.builder(
                  itemCount: productos.length,
                  itemBuilder: (context, index) {
                    final producto = productos[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.inventory_2, color: Colors.white)),
                        title: Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('SKU: ${producto.sku} | Stock: ${producto.stock} | Costo: \$${producto.precioCosto}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('\$${producto.precioVenta.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.orange),
                              onPressed: () => _mostrarFormulario(productoExistente: producto),
                              tooltip: 'Editar',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _eliminar(producto.sku),
                              tooltip: 'Eliminar',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}