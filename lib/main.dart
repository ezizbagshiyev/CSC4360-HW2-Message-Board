import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const demo = bool.fromEnvironment('FIREBASE_EMULATOR');
const host = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Vault());
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final Stream<User?> changes = _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  Future<void> register(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();
}

class Profile {
  Profile(this.fullName);
  final String fullName;
}

class Message {
  Message(this.id, Map<String, dynamic> data)
    : text = data['text'] as String,
      authorUid = data['authorUid'] as String,
      authorName = data['authorName'] as String,
      edited = data['editedAt'] != null;
  final String id, text, authorUid, authorName;
  final bool edited;
}

class BoardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _messages =>
      _db.collection('messages');

  Stream<Profile?> profile(String uid) =>
      _db.collection('users').doc(uid).snapshots().map((doc) {
        final data = doc.data();
        return data == null
            ? null
            : Profile("${data['firstName']} ${data['lastName']}");
      });

  Future<void> saveProfile(String uid, String first, String last) =>
      _db.collection('users').doc(uid).set({
        'uid': uid,
        'firstName': first,
        'lastName': last,
        'role': 'member',
        'registrationDateTime': FieldValue.serverTimestamp(),
      });

  Stream<List<Message>> watch() => _messages
      .orderBy('createdAt')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Message(doc.id, doc.data())).toList(),
      );

  String newPostId() => _messages.doc().id;

  Future<void> post(String id, String uid, Profile profile, String text) async {
    final ref = _messages.doc(id);
    await _db.runTransaction((transaction) async {
      if (!(await transaction.get(ref)).exists) {
        transaction.set(ref, {
          'text': text,
          'authorUid': uid,
          'authorName': profile.fullName,
          'createdAt': FieldValue.serverTimestamp(),
          'editedAt': null,
        });
      }
    });
  }

  Future<void> edit(String id, String text) => _messages.doc(id).update({
    'text': text,
    'editedAt': FieldValue.serverTimestamp(),
  });

  Future<void> delete(String id) => _messages.doc(id).delete();
}

String errorMessage(Object error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Check your email and password and try again.',
      'email-already-in-use' =>
        'This email already has an account. Sign in instead.',
      'weak-password' => 'Choose a stronger password.',
      'permission-denied' => 'Firestore denied this action.',
      'unavailable' ||
      'network-request-failed' => 'Connection unavailable. Try again online.',
      _ => 'The request could not be completed. Try again.',
    };
  }
  return 'Something went wrong. Try again.';
}

class Vault extends StatefulWidget {
  const Vault({super.key});
  @override
  State<Vault> createState() => _VaultState();
}

class _VaultState extends State<Vault> {
  late Future<void> startup = initialize();
  late AuthService auth;
  late BoardService board;

  Future<void> initialize() async {
    final splash = Future<void>.delayed(const Duration(milliseconds: 850));
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: demo
            ? const FirebaseOptions(
                apiKey: 'AIzaSyDemoOnly00000000000000000000000000',
                appId: '1:1234567890:android:1234567890abcdef',
                messagingSenderId: '1234567890',
                projectId: 'demo-message-board',
              )
            : null,
      );
    }
    if (demo) {
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    }
    auth = AuthService();
    board = BoardService();
    await splash;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Message Board Vault',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff334c9c)),
    ),
    home: FutureBuilder<void>(
      future: startup,
      builder: (context, state) {
        if (state.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Firebase could not start. Check the project configuration.',
                  ),
                  FilledButton(
                    onPressed: () => setState(() => startup = initialize()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (state.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.forum_rounded, size: 64),
                  SizedBox(height: 16),
                  Text('Message Board Vault', style: TextStyle(fontSize: 25)),
                  SizedBox(height: 18),
                  CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }
        return StreamBuilder<User?>(
          stream: auth.changes,
          builder: (context, session) {
            if (session.hasError) {
              return const Scaffold(
                body: Center(child: Text('Could not read sign-in state.')),
              );
            }
            if (session.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final user = session.data;
            return user == null
                ? EntryForm(auth: auth, board: board)
                : ProfileGate(
                    key: ValueKey(user.uid),
                    uid: user.uid,
                    auth: auth,
                    board: board,
                  );
          },
        );
      },
    ),
  );
}

class ProfileGate extends StatefulWidget {
  const ProfileGate({
    super.key,
    required this.uid,
    required this.auth,
    required this.board,
  });
  final String uid;
  final AuthService auth;
  final BoardService board;
  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late final profile = widget.board.profile(widget.uid);

  @override
  Widget build(BuildContext context) => StreamBuilder<Profile?>(
    stream: profile,
    builder: (context, state) {
      if (state.hasError) {
        return Scaffold(body: Center(child: Text(errorMessage(state.error!))));
      }
      if (state.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final profile = state.data;
      return profile == null
          ? EntryForm(
              auth: widget.auth,
              board: widget.board,
              pendingUid: widget.uid,
            )
          : BoardPage(
              auth: widget.auth,
              board: widget.board,
              uid: widget.uid,
              profile: profile,
            );
    },
  );
}

class EntryForm extends StatefulWidget {
  const EntryForm({
    super.key,
    required this.auth,
    required this.board,
    this.pendingUid,
  });
  final AuthService auth;
  final BoardService board;
  final String? pendingUid;

  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController();
  final first = TextEditingController(), last = TextEditingController();
  bool register = false, busy = false;
  String? error;

  @override
  void dispose() {
    for (final item in [email, password, first, last]) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    final address = email.text.trim();
    final secret = password.text;
    final firstName = first.text.trim();
    final lastName = last.text.trim();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final pending = widget.pendingUid;
      if (pending != null) {
        await widget.board.saveProfile(pending, firstName, lastName);
      } else if (register) {
        // The profile gate collects the names and allows a retry if that write fails.
        await widget.auth.register(address, secret);
      } else {
        await widget.auth.signIn(address, secret);
      }
    } catch (failure) {
      if (mounted) setState(() => error = errorMessage(failure));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(
    String label,
    TextEditingController controller,
    String? Function(String) check, {
    bool obscure = false,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      enabled: !busy,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) => check(value ?? ''),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pending = widget.pendingUid != null;
    final title = pending
        ? 'Complete your profile'
        : (register ? 'Create account' : 'Sign in');
    String? nameError(String value) {
      final length = value.trim().length;
      return length < 1 || length > 50 ? 'Enter 1–50 characters.' : null;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Message Board Vault')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 22),
                  if (pending) ...[
                    field('First name', first, nameError),
                    field('Last name', last, nameError),
                  ] else ...[
                    field(
                      'Email',
                      email,
                      (value) =>
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(value.trim())
                          ? null
                          : 'Enter a valid email.',
                      keyboard: TextInputType.emailAddress,
                    ),
                    field(
                      'Password',
                      password,
                      (value) => value.length < 6
                          ? 'Enter at least 6 characters.'
                          : null,
                      obscure: true,
                    ),
                  ],
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(
                      busy
                          ? 'Please wait…'
                          : (pending ? 'Save profile' : title),
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (pending) {
                              try {
                                await widget.auth.signOut();
                              } catch (failure) {
                                if (mounted) {
                                  setState(() => error = errorMessage(failure));
                                }
                              }
                            } else {
                              setState(() {
                                register = !register;
                                error = null;
                              });
                            }
                          },
                    child: Text(
                      pending
                          ? 'Sign out'
                          : (register
                                ? 'Already registered? Sign in'
                                : 'Create an account'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BoardPage extends StatefulWidget {
  const BoardPage({
    super.key,
    required this.auth,
    required this.board,
    required this.uid,
    required this.profile,
  });
  final AuthService auth;
  final BoardService board;
  final String uid;
  final Profile profile;
  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  late Stream<List<Message>> messages = widget.board.watch();
  final draft = TextEditingController();
  String? postId;
  bool busy = false;

  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  void feedback(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> write(Future<void> Function() operation) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await operation();
    } catch (error) {
      feedback(errorMessage(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> prompt(Message message, {required bool delete}) async {
    String edited = message.text;
    final form = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(delete ? 'Delete message?' : 'Edit message'),
        content: delete
            ? const Text('This removes the message from the board.')
            : Form(
                key: form,
                child: TextFormField(
                  initialValue: message.text,
                  maxLength: 280,
                  minLines: 2,
                  maxLines: 5,
                  onChanged: (value) => edited = value,
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Enter a message.' : null,
                  decoration: const InputDecoration(labelText: 'Message'),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (delete || form.currentState!.validate()) {
                Navigator.pop(dialog, true);
              }
            },
            child: Text(delete ? 'Delete' : 'Save'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    await write(
      () => delete
          ? widget.board.delete(message.id)
          : widget.board.edit(message.id, edited.trim()),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Message board'),
      actions: [
        IconButton(
          tooltip: 'Sign out',
          onPressed: busy ? null : () => write(widget.auth.signOut),
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: Column(
      children: [
        if (busy) const LinearProgressIndicator(),
        Expanded(
          child: StreamBuilder<List<Message>>(
            stream: messages,
            builder: (context, state) {
              if (state.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(errorMessage(state.error!)),
                      TextButton(
                        onPressed: () =>
                            setState(() => messages = widget.board.watch()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              if (!state.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = state.data!;
              if (items.isEmpty) {
                return const Center(
                  child: Text('No messages yet. Start the conversation.'),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    child: ListTile(
                      title: Text(item.text),
                      subtitle: Text(
                        item.edited
                            ? '${item.authorName} · edited'
                            : item.authorName,
                      ),
                      trailing: item.authorUid == widget.uid
                          ? PopupMenuButton<String>(
                              enabled: !busy,
                              tooltip: 'Message actions',
                              onSelected: (action) =>
                                  prompt(item, delete: action == 'delete'),
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            )
                          : null,
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: draft,
                    enabled: !busy,
                    maxLength: 280,
                    onChanged: (_) => postId = null,
                    decoration: const InputDecoration(
                      labelText: 'New message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () {
                          final text = draft.text.trim();
                          if (text.isEmpty) {
                            feedback('Enter a message first.');
                            return;
                          }
                          final id = postId ??= widget.board.newPostId();
                          write(() async {
                            await widget.board.post(
                              id,
                              widget.uid,
                              widget.profile,
                              text,
                            );
                            if (mounted) {
                              draft.clear();
                              postId = null;
                            }
                          });
                        },
                  child: const Text('Post'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
