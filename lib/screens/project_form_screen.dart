import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/dolibarr_service.dart';
import '../models/project.dart';

class ProjectFormScreen extends StatefulWidget {
  final Project? project;

  const ProjectFormScreen({super.key, this.project});

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _refController;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _dateStartController;
  late TextEditingController _dateEndController;
  late TextEditingController _fkSocController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refController = TextEditingController(text: widget.project?.ref ?? '');
    _titleController = TextEditingController(text: widget.project?.title ?? '');
    _descriptionController = TextEditingController(text: widget.project?.description ?? '');
    _dateStartController = TextEditingController(text: widget.project?.dateStart ?? '');
    _dateEndController = TextEditingController(text: widget.project?.dateEnd ?? '');
    _fkSocController = TextEditingController(text: widget.project?.fkSoc?.toString() ?? '');
  }

  @override
  void dispose() {
    _refController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _dateStartController.dispose();
    _dateEndController.dispose();
    _fkSocController.dispose();
    super.dispose();
  }

  /// Muestra un selector de fecha y actualiza el controlador con el formato YYYY-MM-DD.
  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = picked.toIso8601String().split('T')[0];
    }
  }

  /// Guarda el proyecto (crear o actualizar) vía API de Dolibarr.
  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authService = context.read<AuthService>();
    final dolibarrService = context.read<DolibarrService>();

    final project = Project(
      id: widget.project?.id,
      ref: _refController.text.trim(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      dateStart: _dateStartController.text.trim(),
      dateEnd: _dateEndController.text.trim(),
      fkSoc: _fkSocController.text.trim().isEmpty 
          ? null 
          : int.tryParse(_fkSocController.text.trim()),
    );

    try {
      if (widget.project?.id != null) {
        await dolibarrService.updateProject(
          widget.project!.id!,
          project.toJson(),
          authService.apiKey!,
        );
      } else {
        await dolibarrService.createProject(project.toJson(), authService.apiKey!);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.project?.id != null
                ? 'Proyecto actualizado correctamente'
                : 'Proyecto creado correctamente'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project?.id != null ? 'Editar Proyecto' : 'Nuevo Proyecto'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Información Básica',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _refController,
                      decoration: const InputDecoration(
                        labelText: 'Referencia *',
                        prefixIcon: Icon(Icons.tag),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'La referencia es obligatoria';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título *',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El título es obligatorio';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fechas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dateStartController,
                      decoration: InputDecoration(
                        labelText: 'Fecha de Inicio',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_month),
                          onPressed: () => _selectDate(_dateStartController),
                        ),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dateEndController,
                      decoration: InputDecoration(
                        labelText: 'Fecha de Término',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_month),
                          onPressed: () => _selectDate(_dateEndController),
                        ),
                      ),
                      readOnly: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cliente',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fkSocController,
                      decoration: const InputDecoration(
                        labelText: 'ID del Cliente',
                        prefixIcon: Icon(Icons.business),
                        border: OutlineInputBorder(),
                        helperText: 'ID del tercero asociado al proyecto',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _isLoading ? null : _saveProject,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
