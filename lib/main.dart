import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/common/options.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  await SharedPreferences.getInstance();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override 
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WuKongIM Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

// 登录页面
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _uidController = TextEditingController();
  final _tokenController = TextEditingController();

  Future<void> _login() async {
    try {
      final uid = _uidController.text;
      final token = _tokenController.text;
      
      // 确保数据库目录存在
      final dbDir = await getApplicationDocumentsDirectory();
      await Directory(dbDir.path).create(recursive: true);
      
      // 初始化SDK
      WKIM.shared.setup(Options.newDefault(uid, token));
      
      // 设置IM服务器地址
      WKIM.shared.options.getAddr = (Function(String address) complete) async {
        complete('47.114.111.32:5100');
      };

      // 连接IM服务器
      WKIM.shared.connectionManager.connect();
      
      // 监听连接状态
      WKIM.shared.connectionManager.addOnConnectionStatus('login',
          (status, reason) {
        if (status == WKConnectStatus.success) {
          // 连接成功,跳转到聊天页面
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ChatPage()),
          );
        }
      });
    } catch (e) {
      print('Login error: $e');
      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登录失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _uidController,
              decoration: const InputDecoration(labelText: '用户ID'),
            ),
            TextField(
              controller: _tokenController, 
              decoration: const InputDecoration(labelText: '用户Token'),
            ),
            ElevatedButton(
              onPressed: _login,
              child: const Text('登录'),
            ),
          ],
        ),
      ),
    );
  }
}

// 聊天页面
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<WKMsg> _messages = [];
  final _textController = TextEditingController();
  final String _targetUID = 'tom'; // 替换为实际的目标用户ID

  @override
  void initState() {
    super.initState();
    
    // 监听新消息
    WKIM.shared.messageManager.addOnNewMsgListener('chat', (msgs) {
      setState(() {
        _messages.addAll(msgs);
      });
    });
    
    // 监听消息状态更新
    WKIM.shared.messageManager.addOnRefreshMsgListener('chat', (msg) {
      setState(() {
        final index = _messages.indexWhere((m) => m.clientMsgNO == msg.clientMsgNO);
        if (index != -1) {
          _messages[index] = msg;
        }
      });
    });
  }

  void _sendMessage() {
    if (_textController.text.isEmpty) return;

    // 发送文本消息
    final content = WKTextContent(_textController.text);
    final channel = WKChannel(_targetUID, WKChannelType.personal);
    
    WKIM.shared.messageManager.sendMessage(content, channel);
    
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('聊天')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return ListTile(
                  title: Text(msg.content),
                  subtitle: Text(msg.fromUID),
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
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: '输入消息...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // 移除监听器
    WKIM.shared.messageManager.removeNewMsgListener('chat');
    WKIM.shared.messageManager.removeOnRefreshMsgListener('chat');
    super.dispose();
  }
}
