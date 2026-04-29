import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ClientFavoritesScreen extends StatefulWidget {
  const ClientFavoritesScreen({super.key});

  @override
  State<ClientFavoritesScreen> createState() => _ClientFavoritesScreenState();
}

class _ClientFavoritesScreenState extends State<ClientFavoritesScreen> {
  final List<Map<String, dynamic>> _favorites = [
    {
      'name': 'Casa',
      'address': 'Av. Ejemplo 123, Trujillo',
      'icon': Icons.home,
    },
    {
      'name': 'Trabajo',
      'address': 'Oficina Central, Trujillo',
      'icon': Icons.work,
    },
  ];

  void _showAddFavoriteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text(
          'Agregar Lugar Favorito',
          style: TextStyle(color: AppTheme.darkText),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej: Casa, Trabajo',
              ),
              style: const TextStyle(color: AppTheme.darkText),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Dirección',
                hintText: 'Ingresa la dirección',
              ),
              style: const TextStyle(color: AppTheme.darkText),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Lugar favorito agregado'),
                  backgroundColor: AppTheme.successGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.black,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Lugares Favoritos'),
      ),
      body: SafeArea(
        child: _favorites.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star_border,
                      size: 64,
                      color: AppTheme.darkTextSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No tienes lugares favoritos',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppTheme.darkTextSecondary,
                          ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _favorites.length,
                itemBuilder: (context, index) {
                  final favorite = _favorites[index];
                  return _buildFavoriteCard(context, favorite);
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFavoriteDialog,
        backgroundColor: AppTheme.primaryBlue,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildFavoriteCard(BuildContext context, Map<String, dynamic> favorite) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              favorite['icon'],
              color: AppTheme.primaryBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  favorite['name'],
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.darkText,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  favorite['address'],
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.darkTextSecondary,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            color: AppTheme.darkTextSecondary,
            onPressed: () {
              // TODO: Navegar a detalles o editar
            },
          ),
        ],
      ),
    );
  }
}
