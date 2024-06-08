import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:vibration/vibration.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:updater/updater.dart'; // Add the updater package

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(AppMain()); // Change MyApp to AppMain
}

class AppMain extends StatelessWidget {
  static final _defaultLightColorScheme =
      ColorScheme.fromSwatch(primarySwatch: Colors.blue);

  static final _defaultDarkColorScheme = ColorScheme.fromSwatch(
      primarySwatch: Colors.blue, brightness: Brightness.dark);
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightColorScheme, darkColorScheme) {
      return MaterialApp(
        title: 'VSC',
        theme: ThemeData(
          colorScheme: lightColorScheme ?? _defaultLightColorScheme,
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            color: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.black,
          appBarTheme: const AppBarTheme(
            color: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
        ),
        themeMode: ThemeMode.system,
        home: MyApp(),
      );
    });
  }
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late UpdaterController controller;
  late Updater updater;

  @override
  void initState() {
    super.initState();
    initializeUpdater();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void initializeUpdater() {
    controller = UpdaterController(
      listener: (UpdateStatus status) {
        debugPrint('Listener: $status');
      },
      onChecked: (bool isAvailable) {
        debugPrint('$isAvailable');
      },
      progress: (current, total) {
        // debugPrint('Progress: $current -- $total');
      },
      onError: (status) {
        debugPrint('Error: $status');
      },
    );

    updater = Updater(
      context: context,
      delay: const Duration(milliseconds: 300),
      url: 'https://my.api.mockaroo.com/updater.json?key=e91cdf00',
      titleText: 'Update Available',
      allowSkip: true,
      contentText: 'Update your app to the latest version.',
      callBack: (UpdateModel model) {
        debugPrint(model.versionName);
        debugPrint(model.versionCode.toString());
        debugPrint(model.contentText);
      },
      enableResume: true,
      controller: controller,
    );

    // Check for update every time the app is opened
    checkUpdate();
  }

  checkUpdate() async {
    bool isAvailable = await updater.check();
    debugPrint('$isAvailable');
  }

  @override
  Widget build(BuildContext context) {
    return ChatScreen(); // Return ChatScreen directly
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  TextEditingController _messageController = TextEditingController();

  void _sendMessage() {
    String message = _messageController.text.trim();
    if (message.isNotEmpty) {
      FirebaseFirestore.instance.collection('chat').add({
        'msg': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isAdmin': true,
      });
      _messageController.clear();
    }
  }

  void _deleteMessage(DocumentSnapshot document) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            // Convert epoch time to DateTime and format it with AM/PM and date
            DateFormat('MMM dd, yyyy hh:mm a').format(
              DateTime.fromMillisecondsSinceEpoch(document['timestamp']),
            ),
          ),
          content: Text("Are you sure you want to delete this message?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                if (document['msg'].startsWith(
                    'https://firebasestorage.googleapis.com/v0/b/')) {
                  // Delete the image from Storage
                  await _deleteImageFromStorage(document['msg']);
                }
                FirebaseFirestore.instance
                    .collection('chat')
                    .doc(document.id)
                    .delete();
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text("Delete"),
            ),
          ],
        );
      },
    );
    // Add vibration feedback
    Vibration.vibrate(duration: 50);
  }

  Future<void> _deleteImageFromStorage(String imageUrl) async {
    try {
      // Extract the image path from the URL
      final storageRef = FirebaseStorage.instance.refFromURL(imageUrl);
      // Delete the image
      await storageRef.delete();
    } on FirebaseException catch (e) {
      print('Error deleting image: ${e.code} - ${e.message}');
      // Handle potential errors during deletion (optional)
    }
  }

  void _uploadFile() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      // Upload the image to Firebase Storage (replace with your storage logic)
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = storageRef.putFile(File(pickedFile.path));
      final snapshot = await uploadTask.whenComplete(() => null);
      final downloadUrl = await snapshot.ref.getDownloadURL();
      // Send the download URL as the message
      FirebaseFirestore.instance.collection('chat').add({
        'msg': downloadUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isAdmin': true,
      });
    }
  }

  void _viewPhoto(DocumentSnapshot document) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Container(
            child: PhotoView(
          imageProvider: NetworkImage(document['msg']),
        ));
      },
    );
    // Add vibration feedback
    Vibration.vibrate(duration: 50);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('VS Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('chat')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (BuildContext context,
                  AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('No Messages Found'),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (BuildContext context, int index) {
                    DocumentSnapshot document = snapshot.data!.docs[index];
                    Map<String, dynamic> data =
                        document.data() as Map<String, dynamic>;
                    String message = data['msg'];
                    bool isAdmin = data['isAdmin'] ?? false;

                    final isImageURL = message.startsWith(
                        'https://firebasestorage.googleapis.com/v0/b/');
                    return GestureDetector(
                      onTap: () => _deleteMessage(document),
                      onLongPress: () {
                        isImageURL
                            ? _viewPhoto(document)
                            : Clipboard.setData(ClipboardData(text: message));
                        Vibration.vibrate(duration: 50);
                      },
                      child: BubbleSpecialThree(
                        text: isImageURL ? 'Photo' : message,
                        color: isAdmin ? Color(0xFF1B97F3) : Color(0xFFE8E8EE),
                        textStyle: isAdmin
                            ? TextStyle(color: Colors.white, fontSize: 16)
                            : TextStyle(color: Colors.black, fontSize: 16),
                        tail: false,
                        isSender: isAdmin,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                    child: TextField(
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  controller: _messageController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide(
                        width: 0,
                        style: BorderStyle.none,
                      ),
                    ),
                    fillColor: const Color.fromARGB(255, 38, 38, 38),
                    filled: true,
                    contentPadding: EdgeInsets.symmetric(
                        vertical: 10.0,
                        horizontal: 15.0), // Adjust vertical padding
                    prefixIcon: IconButton(
                      onPressed:
                          _uploadFile, // Call _uploadFile on button press
                      icon: Icon(Icons.attach_file), // Use upload_file icon
                      iconSize: 24.0,
                    ),
                    suffixIcon: IconButton(
                      onPressed: _sendMessage,
                      icon: Icon(Icons.send),
                      iconSize: 24.0, // Adjust icon size
                    ),
                    hintText: 'Enter your message',
                  ),
                )),
                SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
