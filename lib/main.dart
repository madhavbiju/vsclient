import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:vibration/vibration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize FCM for background messages
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(AppMain());
}

// Background FCM handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

class AppMain extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VS Client',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,  // AMOLED black background
        primaryColor: Colors.black,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black, // Black AppBar in dark mode
        ),
      ),
      themeMode: ThemeMode.system,
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  TextEditingController _messageController = TextEditingController();
  ScrollController _scrollController = ScrollController();
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    _initializeFCM();
    _initializeLocalNotifications();
  }

  void _initializeFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission for notifications
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          _showNotification(message.notification!);
        }
      });

      // Token for sending notifications
      String? token = await messaging.getToken();
      print("FCM Token: $token");

      // Subscribe to topic for notifications
      messaging.subscribeToTopic('new_messages');
    } else {
      print('User declined or has not accepted permission');
    }
  }

  void _initializeLocalNotifications() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification(RemoteNotification notification) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'channel_id',
      'channel_name',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_stat_untitled_1',
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      notification.title,
      notification.body,
      platformChannelSpecifics,
    );
  }

  void _sendMessage() {
    String message = _messageController.text.trim();
    if (message.isNotEmpty) {
      FirebaseFirestore.instance.collection('chat').add({
        'msg': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isAdmin': true, // Change to true for admin messages
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
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = storageRef.putFile(File(pickedFile.path));
      final snapshot = await uploadTask.whenComplete(() => null);
      final downloadUrl = await snapshot.ref.getDownloadURL();
      FirebaseFirestore.instance.collection('chat').add({
        'msg': downloadUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isAdmin': true, // Change to false for non-admin
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
      centerTitle: true,
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
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No Messages Found'));
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                }
              });

              return ListView.builder(
                controller: _scrollController,
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
                      text: isImageURL ? 'Photo 📸' : message,
                      color: isImageURL
                          ? Color(0xFF009759)
                          : (isAdmin
                              ? Color(0xFF1770e0)
                              : Color(0xFFE8E8EE)),
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
            child:
        Row(
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
          filled: true,
          contentPadding: EdgeInsets.symmetric(
            vertical: 10.0,
            horizontal: 15.0,
          ),
          prefixIcon: IconButton(
            onPressed: _uploadFile, // Call _uploadFile on button press
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
      ),
    ),// Optional padding on the right
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
    _scrollController.dispose();
    super.dispose();
  }
}
