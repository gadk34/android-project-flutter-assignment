import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:provider/provider.dart';
import 'package:snapping_sheet/snapping_sheet.dart';
import 'user_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
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

class RandomWords extends StatefulWidget {
  @override
  _RandomWordsState createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  final _suggestions = <WordPair>[];
  final _saved = Set<WordPair>();
  final _biggerFont = const TextStyle(color: Colors.black, fontSize: 18);
  SnappingSheetController _snapCtrl = SnappingSheetController();

  @override
  Widget build(BuildContext context) {
    final _scaffoldKey = GlobalKey<ScaffoldState>();

    return Material(
      child: Consumer<UserRepository>(
        builder: (context, userRep, _) {
          var _list = Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
              title: Text('Startup Name Generator'),
              actions: userRep.status == Status.Authenticated
                  ? [
                IconButton(icon: Icon(Icons.favorite), onPressed: () => _pushSaved()),
                Builder(
                  builder: (context) =>
                      IconButton(
                          icon: Icon(Icons.exit_to_app),
                          onPressed: () {
                            userRep.signOut();
                            _saved.clear();
                            Scaffold.of(context).showSnackBar(SnackBar(
                              content: Text("Logged out successfully"),
                              behavior: SnackBarBehavior.floating,
                            ));
                          }),
                ),
              ]
                  : [
                IconButton(icon: Icon(Icons.favorite), onPressed: () => _pushSaved()),
                IconButton(icon: Icon(Icons.login), onPressed: () => _pushLogin()),
              ],
            ),
            resizeToAvoidBottomInset: true,
            body: _buildSuggestions(),
          );
          final _snapPosis = [
            SnapPosition(
                positionPixel: 0.0,
                snappingCurve: Curves.elasticOut,
                snappingDuration: Duration(milliseconds: 750)),
            SnapPosition(
                positionPixel: MediaQuery
                    .of(context)
                    .size
                    .height * 0.14,
                snappingCurve: Curves.elasticOut,
                snappingDuration: Duration(milliseconds: 750)),
          ];
          return userRep.status == Status.Authenticated
              ? SnappingSheet(
            sheetBelow: SnappingSheetContent(
                  child: Container(
                    alignment: Alignment.topCenter,
                    padding: EdgeInsets.all(2),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.transparent,
                              backgroundImage: userRep.avatarURL == null
                                  ? null
                                  : NetworkImage(userRep.avatarURL),
                              child: userRep.avatarURL == null ? Center(child: Text(
                                  "${userRep.user.email[0].toUpperCase()}",
                                  style: TextStyle(color: Colors.black,
                                      fontSize: 50,
                                      fontWeight: FontWeight.bold))) : null,
                              radius: MediaQuery
                                  .of(context)
                                  .size
                                  .height * 0.06,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text("${userRep.user.email}", style: _biggerFont),
                                    RaisedButton(
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                18.0)),
                                        color: Colors.teal,
                                        onPressed: () async {
                                          try {
                                            await userRep.addAvatar();
                                          } on NoSuchMethodError catch (_) {
                                            _scaffoldKey.currentState.showSnackBar(SnackBar(
                                              content: Container(
                                                  height: _snapCtrl.currentSnapPosition.positionPixel + 60,
                                                  child: Text("No image selected")),
                                              behavior: SnackBarBehavior.floating,
                                              elevation: null,
                                            ));
                                          }
                                        },
                                        child: Center(child: Text("Change avatar",
                                            style: TextStyle(color: Colors.white))))
                                  ],
                                ),
                              ),
                            ),
                          ]),
                    ),
                  ),
                  draggable: true,
                  heightBehavior: SnappingSheetHeight.fit()),
            snappingSheetController: _snapCtrl,
            grabbing: InkWell(
                onTap: () {
                  setState(() {
                    _snapCtrl.snapToPosition(_snapPosis[_snapCtrl.currentSnapPosition == _snapPosis[1] ? 0 : 1]);
                  });
                },
                child: Container(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Welcome back, ${userRep.user.email}!",
                          style: _biggerFont),
                      Icon(Icons.keyboard_arrow_up),
                    ],
                  ),
                  color: Colors.grey,
                  padding: EdgeInsets.all(10),
                ),

            ),
            grabbingHeight: MediaQuery
                  .of(context)
                  .size
                  .height * 0.075,
            child: _list,
            snapPositions: _snapPosis,
            initSnapPosition: _snapPosis[0],
          )
              : _list;
        },
      ),
    );
  }

  WordPair _stringToWordPair(String s) {
    //Assuming the string has 2 capital letters
    final index = s.lastIndexOf(RegExp(r"[A-Z]"));
    return WordPair(s.substring(0, index).toLowerCase(), s.substring(index, s.length).toLowerCase());
  }

  void _pushLogin() {
    final _emailCtrl = TextEditingController();
    final _passwordCtrl = TextEditingController();

    var _loginPage = MaterialPageRoute<void>(
      builder: ((BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) =>
              Consumer<UserRepository>(builder: (context, userRep, _) {
                return Scaffold(
                  // resizeToAvoidBottomInset: false,
                  appBar: AppBar(
                    title: Text('Login'),
                  ),
                  body: Container(
                    alignment: Alignment.topCenter,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SizedBox(height: 10),
                        Text(
                            'Welcome to my homework! Please fill the fields below:',
                            style: _biggerFont),
                        SizedBox(height: 10),
                        TextField(
                          controller: _emailCtrl,
                          style: _biggerFont,
                          decoration: InputDecoration(
                            hintText: 'Email',
                            icon: Icon(Icons.mail),
                          ),
                        ),
                        SizedBox(height: 10),
                        TextField(
                          controller: _passwordCtrl,
                          style: _biggerFont,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            icon: Icon(Icons.vpn_key),
                          ),
                          obscureText: true,
                        ),
                        SizedBox(height: 10),
                        Builder(
                          builder: ((context) {
                            switch (userRep.status) {
                              case Status.Uninitialized:
                              case Status.Unauthenticated:
                                return RaisedButton(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          18.0)),
                                  color: Colors.red,
                                  onPressed: () async {
                                    try {
                                      await userRep.signIn(
                                          _emailCtrl.text, _passwordCtrl.text);
                                      await userRep.syncSavedFavorites(_saved);
                                    } on FirebaseAuthException catch (_) {
                                      Scaffold.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              "There was an error logging into the app"),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    'Log in',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 18),
                                  ),
                                );
                              case Status.Authenticating:
                                return Center(
                                    child: CircularProgressIndicator());
                              default:
                                Navigator.of(context).pop();
                                return Column(children: [
                                  Center(child: Text(
                                      "Already logged in! Please return to the main page")),
                                  RaisedButton(
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            18.0)),
                                    color: Colors.red,
                                    onPressed: () {
                                      userRep.signOut();
                                      setState(() => _saved.clear());
                                      Scaffold.of(context).showSnackBar(
                                          SnackBar(content: Text(
                                              "Logged out successfully"),
                                            behavior: SnackBarBehavior.floating,
                                          ));
                                    },
                                    child: Text("sign out"),
                                  )
                                ]);
                            }
                          }),
                        ),
                        Builder(
                          builder: (context) =>
                              RaisedButton(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          18.0)),
                                  color: Colors.teal,
                                  onPressed: () {
                                    if (_passwordCtrl.text.isNotEmpty &&
                                        _emailCtrl.text.isNotEmpty) {
                                      // TODO try the bonus - blur the background based on the bottom sheet's height (use the controller)
                                      showModalBottomSheet(
                                          isScrollControlled: true,
                                          context: context,
                                          builder: (context) {
                                            final _passConfirmCtrl = TextEditingController();
                                            var _passwordValid = true;
                                            return Padding(
                                              padding: MediaQuery
                                                  .of(context)
                                                  .viewInsets,
                                              child: StatefulBuilder(
                                                builder: (context, setState) =>
                                                    Container(
                                                      child: Column(
                                                        mainAxisAlignment: MainAxisAlignment
                                                            .start,
                                                        mainAxisSize: MainAxisSize.min,
                                                        crossAxisAlignment: CrossAxisAlignment
                                                            .center,
                                                        children: [
                                                          Text(
                                                              "Please confirm your password below:",
                                                              style: _biggerFont),
                                                          TextField(
                                                            controller: _passConfirmCtrl,
                                                            autofocus: true,
                                                            style: _biggerFont,
                                                            decoration: InputDecoration(
                                                              hintText: 'Confirm password',
                                                              icon: Icon(Icons
                                                                  .vpn_key_outlined),
                                                              errorText: _passwordValid ? null : "Passwords must match",
                                                            ),
                                                            obscureText: true,
                                                            onTap: () => setState(() => _passwordValid = true),
                                                          ),
                                                          RaisedButton(
                                                              shape: RoundedRectangleBorder(
                                                                  borderRadius: BorderRadius
                                                                      .circular(18.0)),
                                                              color: Colors.teal,
                                                              onPressed: () async {
                                                                try {
                                                                  if (_passConfirmCtrl.text.isNotEmpty && _passConfirmCtrl.text.compareTo(_passwordCtrl.text) == 0) {
                                                                    await userRep.signUp(_emailCtrl.text, _passwordCtrl.text, _passConfirmCtrl.text);
                                                                    setState(() => _passwordValid = true);
                                                                    await userRep.syncSavedFavorites(_saved);
                                                                    Navigator.of(context).pop(); //pops the modal bottom sheet;
                                                                  } else {
                                                                    setState(() => _passwordValid = false);
                                                                  }
                                                                } on FirebaseAuthException catch (_) {
                                                                  Scaffold.of(context).showSnackBar(
                                                                    SnackBar(
                                                                      content: Text(
                                                                          "There was an error logging into the app"),
                                                                      behavior: SnackBarBehavior.floating,
                                                                    ),
                                                                  );
                                                                }
                                                              },
                                                              child: Text("Confirm",
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize: 18)))
                                                        ],
                                                      ),
                                                    ),
                                              ),
                                            );
                                          });
                                    }
                                  },
                                  child: Center(child: Text(
                                      "New user? Click to sign up",
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 18)))),
                        )
                      ],
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
    Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (BuildContext context) {
          return Consumer<UserRepository>(
            builder: (context, userRep, _) =>
                FutureBuilder(
                    future: (() async {
                      return userRep.status == Status.Authenticated
                          ? await userRep.firestore
                          .collection('users')
                          .doc(userRep.user.email)
                          .get()
                          .then((ref) =>
                          ref.data()['favorites'].map<WordPair>((s) =>
                              _stringToWordPair(s)))
                          : _saved;
                    })(),
                    builder: (context, snapshot) =>
                        Scaffold(
                          appBar: AppBar(
                            title: Text('Saved Suggestions'),
                          ),
                          body: snapshot.hasData
                              ? ListView(
                            children: ListTile.divideTiles(
                              context: context,
                              tiles: snapshot.data
                                  .toList()
                                  .map<Widget>((WordPair pair) =>
                                  ListTile(
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
