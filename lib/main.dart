// allaboutflutter.com

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

enum SortOrder { ascending, descending }

final deviceInfoPlugin = DeviceInfoPlugin();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const ShowFilesScreen(),
    );
  }
}

class ShowFilesScreen extends StatefulWidget {
  const ShowFilesScreen({super.key});

  @override
  State<ShowFilesScreen> createState() => _ShowFilesScreenState();
}

class _ShowFilesScreenState extends State<ShowFilesScreen> {
  Directory directory = Directory('/storage/emulated/0');
  List<FileSystemEntity> files = [];
  SortOrder sortOrder = SortOrder.ascending;
  bool loading = true;

  int selectedFileIndex = -1;

  void sortFileSystemItems() {
    if (sortOrder == SortOrder.ascending) {
      files.sort((a, b) {
        return a.path.compareTo(b.path);
      });
    } else {
      files.sort((a, b) {
        return b.path.compareTo(a.path);
      });
    }

    setState(() {});
  }

  Future<void> getFiles() async {
    setState(() {
      loading = true;
    });
    PermissionStatus status = await Permission.manageExternalStorage.request();

    if (status.isGranted == false) {}
    if (await directory.exists() == false) {
      return;
    }
    files = directory.listSync();

    sortFileSystemItems();

    setState(() {
      loading = false;
    });
  }

  void renameFile(FileSystemEntity file) async {
    final TextEditingController controller = TextEditingController(
      text: file.path.split('/').last.split('.').first,
    );
    bool edit = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename File'),
          content: TextField(
            controller: controller,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    if (edit == false) {
      return;
    }
    String newFileName =
        '${controller.text}.${file.path.split('/').last.split('.').last}';
    String newPath =
        '${file.path.split('/').sublist(0, file.path.split('/').length - 1).join('/')}/$newFileName';

    file.renameSync(newPath);

    getFiles();
  }

  void deleteFile(FileSystemEntity file) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete File'),
          content: const Text('Are you sure you want to delete?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                file.deleteSync();
                getFiles();
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void onBackPress() {
    if (selectedFileIndex != -1) {
      setState(() {
        selectedFileIndex = -1;
      });
      return;
    }
    if (directory.path != '/storage/emulated/0') {
      directory = directory.parent;
      getFiles();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    getFiles();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          onBackPress();
        },
        child: Scaffold(
          body: FutureBuilder(
              future: deviceInfoPlugin.androidInfo,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                } else {
                  if (snapshot.hasData) {
                    AndroidDeviceInfo info = snapshot.data!;
                    return Scaffold(
                      appBar: AppBar(
                        title: Text(
                          selectedFileIndex == -1
                              ? '${info.device} Manager'
                              : files[selectedFileIndex].path.split('/').last,
                        ),
                        leading: directory.path == '/storage/emulated/0'
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () {
                                  onBackPress();
                                }),
                      ),
                      bottomSheet: Visibility(
                        visible: selectedFileIndex != -1,
                        child: BottomAppBar(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  if (files[selectedFileIndex] is File) {
                                    deleteFile(files[selectedFileIndex]);
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () {
                                  if (files[selectedFileIndex] is File) {
                                    renameFile(files[selectedFileIndex]);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      body: Visibility(
                        visible: files.isNotEmpty || loading,
                        replacement: const Center(
                          child: Text('No files to show!'),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(directory.path),
                                  // dropdown for sorting
                                  DropdownButton<String>(
                                    value: sortOrder == SortOrder.ascending
                                        ? 'Ascending'
                                        : 'Descending',
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        sortOrder = newValue == 'Ascending'
                                            ? SortOrder.ascending
                                            : SortOrder.descending;
                                      });
                                      sortFileSystemItems();
                                    },
                                    items: <String>['Ascending', 'Descending']
                                        .map<DropdownMenuItem<String>>(
                                            (String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                  )
                                ],
                              ),
                            ),
                            Visibility(
                              visible: !loading,
                              replacement: const LinearProgressIndicator(),
                              child: Expanded(
                                child: ListView.builder(
                                  itemCount: files.length,
                                  itemBuilder: (context, index) {
                                    return ListTile(
                                      selected: selectedFileIndex == index,
                                      selectedTileColor: Colors.purple.shade100,
                                      title: Text(
                                          files[index].path.split('/').last),
                                      leading: Icon(files[index] is File
                                          ? Icons.file_open
                                          : Icons.folder),
                                      onTap: () {
                                        if (files[index] is Directory) {
                                          directory = files[index] as Directory;
                                          getFiles();
                                        } else if (files[index] is File) {
                                          OpenFilex.open(files[index].path);
                                        }
                                      },
                                      onLongPress: () {
                                        setState(() {
                                          selectedFileIndex = index;
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                }
                return const CircularProgressIndicator();
              }),
        ));
  }
}
