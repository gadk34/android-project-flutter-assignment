import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:english_words/english_words.dart';
import 'package:image_picker/image_picker.dart';

enum Status { Uninitialized, Authenticated, Authenticating, Unauthenticated }

class UserRepository with ChangeNotifier {
  FirebaseAuth _auth;
  User _user;
  Status _status = Status.Uninitialized;
  FirebaseFirestore _db;
  FirebaseStorage _storage;
  String _avatarURL;

  UserRepository.instance() : _auth = FirebaseAuth.instance {
    _auth.authStateChanges().listen(_authStateChanges);
  }

  Status get status => _status;
  User get user => _user;
  FirebaseAuth get auth => _auth;
  FirebaseFirestore get firestore => _db;
  FirebaseStorage get storage => _storage;
  String get avatarURL => _avatarURL;

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
      _storage = FirebaseStorage.instance;
      _avatarURL = await _storage.ref().child("images/${_user.email}_avatar").getDownloadURL();
      await _addUser(_db.collection('users').doc(_user.email));
      notifyListeners();
    } catch (e) {
      _status = Status.Unauthenticated;
      notifyListeners();
      throw e;
    }
  }

  Future signUp(String email, String password, String passwordValidate) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
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

  Future addAvatar() async {
    final _picker = ImagePicker();

    await _picker.getImage(source: ImageSource.gallery).then((image) async {
      await _storage.ref().child("images/${_user.email}_avatar").putFile(File(image.path));
      _avatarURL = await _storage.ref().child("images/${_user.email}_avatar").getDownloadURL();;
    });
    notifyListeners();
  }
}