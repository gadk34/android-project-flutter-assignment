import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(
                  child: Text(
            snapshot.error.toString(),
            textDirection: TextDirection.ltr,
          )));
        }

        if (snapshot.connectionState == ConnectionState.done) {
          return MyApp();
        }

        return Center(child: CircularProgressIndicator());
      },
    );
  }
}

enum Status { Uninitialized, Authenticated, Authenticating, Unauthenticated }

class UserRepository with ChangeNotifier {
  FirebaseAuth _auth;
  User _user;
  Status _status = Status.Uninitialized;
  FirebaseFirestore _db;

  UserRepository.instance() : _auth = FirebaseAuth.instance {
    _auth.authStateChanges().listen(_authStateChanges);
  }

  Status get status => _status;

  User get user => _user;

  FirebaseAuth get auth => _auth;

  FirebaseFirestore get firestore => _db;

  Future<void> _addUser(DocumentReference userRef) async {
    userRef.get().then((snapshot) {
      if (!snapshot.exists) {
        userRef.set({'email': _user.email, 'favorites': []});
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _status = Status.Authenticated;
      _db = FirebaseFirestore.instance;
      await _addUser(_db.collection('users').doc(_user.email));
      notifyListeners();
    } catch (e) {
      _status = Status.Unauthenticated;
      notifyListeners();
      throw e;
    }
  }

  Future signOut() async {
    _status = Status.Unauthenticated;
    _auth.signOut();
    _db = null;
    notifyListeners();
    return Future.delayed(Duration.zero);
  }

  Future syncSavedFavorites(Set saved) async {
    if (status == Status.Authenticated) {
      _db.collection('users').doc(_user.email).get().then((snapshot) async {
        var currFaves = Set.from(snapshot.data()['favorites']);
        currFaves.addAll(
            saved.map<String>((f) => f.asPascalCase.toString()).toList());
        await _db
            .collection('users')
            .doc(_user.email)
            .update({'favorites': currFaves.toList()});
      });
      _db.collection('users').doc(_user.email).get().then((snapshot) async {
        var currFaves = Set.from(snapshot.data()['favorites']);
        saved = saved.union(currFaves);
      });
      notifyListeners();
    }
  }

  Future addFavorite(WordPair pair, Set<WordPair> saved) async {
    saved.add(pair);
    if (status == Status.Authenticated) {
      _db.collection('users').doc(_user.email).get().then((snapshot) async {
        var currFaves = snapshot.data()['favorites'];
        currFaves.add(pair.asPascalCase.toString());
        await _db
            .collection('users')
            .doc(_user.email)
            .update({'favorites': currFaves.toList()});
        notifyListeners();
      });
    }
  }

  Future removeFavorite(WordPair pair, Set saved) async {
    saved.remove(pair);
    if (status == Status.Authenticated) {
      _db.collection('users').doc(_user.email).get().then((snapshot) async {
        var currFaves = Set<String>.from(snapshot.data()['favorites']);
        currFaves.remove(pair.asPascalCase.toString());
        await _db
            .collection('users')
            .doc(_user.email)
            .update({'favorites': currFaves.toList()});
        notifyListeners();
      });
    }
  }

  Future<void> _authStateChanges(User firebaseUser) async {
    if (firebaseUser == null) {
      _status = Status.Unauthenticated;
    } else {
      _user = firebaseUser;
      _status = Status.Authenticated;
    }
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UserRepository>(
      create: (_) => UserRepository.instance(),
      child: MaterialApp(
        title: 'Startup Name Generator',
        theme: ThemeData(
          primaryColor: Colors.red,
        ),
        home: RandomWords(),
      ),
    );
  }
}

class RandomWords extends StatefulWidget {
  @override
  _RandomWordsState createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  final _suggestions = <WordPair>[];
  final _saved = Set<WordPair>();
  final _biggerFont = const TextStyle(fontSize: 18);

  @override
  Widget build(BuildContext context) {
    return Consumer<UserRepository>(
      builder: (context, userRep, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Startup Name Generator'),
            actions: userRep.status == Status.Authenticated
                ? [
                    IconButton(
                        icon: Icon(Icons.favorite),
                        onPressed: () => _pushSaved()),
                    Builder(
                      builder: (context) => IconButton(
                          icon: Icon(Icons.exit_to_app),
                          onPressed: () {
                            userRep.signOut();
                            _saved.clear();
                            Scaffold.of(context).showSnackBar(SnackBar(
                                content: Text("Logged out successfully")));
                          }),
                    ),
                  ]
                : [
                    IconButton(
                        icon: Icon(Icons.favorite),
                        onPressed: () => _pushSaved()),
                    IconButton(
                        icon: Icon(Icons.login),
                        onPressed: () => _pushLogin(userRep)),
                  ],
          ),
          body: _buildSuggestions(),
        );
      },
    );
  }

  WordPair _stringToWordPair(String s) {
    //Assuming the string has 2 capital letters
    final index = s.lastIndexOf(RegExp(r"[A-Z]"));
    return WordPair(s.substring(0, index).toLowerCase(),
        s.substring(index, s.length).toLowerCase());
  }

  void _pushLogin(UserRepository userRep) {
    final _formKey = GlobalKey<FormState>();
    final _emailCtrl = TextEditingController();
    final _passwordCtrl = TextEditingController();

    var _loginPage = MaterialPageRoute<void>(
      builder: ((BuildContext context) {
        return Builder(
          builder: (context) =>
              Consumer<UserRepository>(builder: (context, userRep, _) {
            return Scaffold(
              resizeToAvoidBottomInset: false,
              appBar: AppBar(
                title: Text('Login'),
              ),
              body: Builder(
                builder: (context) => Form(
                  key: _formKey,
                  child: Container(
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: <Widget>[
                          SizedBox(height: 10),
                          Text(
                              'Welcome to my homework! Please fill the fields below:',
                              style: _biggerFont),
                          SizedBox(height: 10),
                          TextFormField(
                            controller: _emailCtrl,
                            style: _biggerFont,
                            decoration: InputDecoration(
                                hintText: 'Email', icon: Icon(Icons.mail)),
                          ),
                          SizedBox(height: 10),
                          TextFormField(
                            controller: _passwordCtrl,
                            style: _biggerFont,
                            decoration: InputDecoration(
                                hintText: 'Password',
                                icon: Icon(Icons.vpn_key)),
                            obscureText: true,
                          ),
                          SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Builder(
                              builder: ((context) {
                                switch (userRep.status) {
                                  case Status.Uninitialized:
                                  case Status.Unauthenticated:
                                    return ElevatedButton(
                                      onPressed: () async {
                                        try {
                                          await userRep.signIn(_emailCtrl.text,
                                              _passwordCtrl.text);
                                          await userRep
                                              .syncSavedFavorites(_saved);
                                          if (userRep.status ==
                                              Status.Authenticated) {
                                            Navigator.of(context).pop();
                                          }
                                        } on FirebaseAuthException catch (_) {
                                          Scaffold.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  "There was an error logging into the app"),
                                            ),
                                          );
                                        }
                                      },
                                      child: Text(
                                        'Submit',
                                        style: _biggerFont,
                                      ),
                                    );
                                  case Status.Authenticating:
                                    return Center(
                                        child: CircularProgressIndicator());
                                  default:
                                    return Column(children: [
                                      Center(
                                          child: Text(
                                              "Already logged in! Please return to the main page")),
                                      ElevatedButton(
                                        onPressed: () {
                                          userRep.signOut();
                                          _saved.clear();
                                          Scaffold.of(context).showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      "Logged out successfully")));
                                        },
                                        child: Text("sign out"),
                                      )
                                    ]);
                                }
                              }),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );

    Navigator.of(context).push(_loginPage);
  }

  void _pushSaved() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (BuildContext context) {
      return Consumer<UserRepository>(
        builder: (context, userRep, _) => FutureBuilder(
            future: (() async {
              return userRep.status == Status.Authenticated
                  ? await userRep.firestore
                      .collection('users')
                      .doc(userRep.user.email)
                      .get()
                      .then((ref) => ref
                          .data()['favorites']
                          .map<WordPair>((s) => _stringToWordPair(s)))
                  : _saved;
            })(),
            builder: (context, snapshot) => Scaffold(
                  appBar: AppBar(
                    title: Text('Saved Suggestions'),
                  ),
                  body: snapshot.hasData
                      ? ListView(
                          children: ListTile.divideTiles(
                            context: context,
                            tiles: snapshot.data
                                .toList()
                                .map<Widget>((WordPair pair) => ListTile(
                                      title: Text(
                                        pair.asPascalCase,
                                        style: _biggerFont,
                                      ),
                                      trailing: IconButton(
                                          icon: Icon(
                                            Icons.delete,
                                            color: Colors.black,
                                          ),
                                          onPressed: () async {
                                            await userRep.removeFavorite(
                                                pair, _saved);
                                            setState(() {});
                                          }),
                                    ))
                                .toList(),
                          ).toList(),
                        )
                      : Center(child: CircularProgressIndicator()),
                )),
      );
    }));
  }

  Widget _buildSuggestions() {
    _suggestions.addAll(generateWordPairs().take(10).toList());
    return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemBuilder: (BuildContext _context, int i) {
          if (i.isOdd) {
            return Divider();
          }
          final int index = i ~/ 2;
          if (index >= _suggestions.length) {
            _suggestions.addAll(generateWordPairs().take(10));
          }
          return _buildRow(_suggestions[index]);
        });
  }

  Widget _buildRow(WordPair pair) {
    return Consumer<UserRepository>(builder: (context, userRep, _) {
      final alreadySaved = _saved.contains(pair);

      return ListTile(
          title: Text(
            pair.asPascalCase,
            style: _biggerFont,
          ),
          trailing: alreadySaved
              ? Icon(Icons.favorite, color: Colors.red)
              : Icon(
                  Icons.favorite_border,
                  color: null,
                ),
          onTap: () async {
            if (alreadySaved) {
              await userRep.removeFavorite(pair, _saved);
            } else {
              await userRep.addFavorite(pair, _saved);
            }
            setState(() {});
          });
    });
  }
}
