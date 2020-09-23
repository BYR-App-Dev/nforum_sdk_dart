import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:nforum_sdk/request.dart';

import 'nforum_structures.dart';

class Secrets {
  static String clientID;
  static String appleID;
  static String bundleID;
  static String identifier;
  static String welcomeSalt;
  static String tokenDir;
}

class AppConfigs {
  static bool isIPv6Used;
}

class PageConfig {
  static const int pageItemCount = 20;
}

class Helper {
  static String getEnumValue(dynamic t) {
    return t.toString().split('.').last;
  }

  static String getStrippedEnumValue(dynamic t) {
    return getEnumValue(t).split('_').last;
  }
}

class NForumSpecs {
  static String get bbsURL => AppConfigs.isIPv6Used ? 'https://bbs6.byr.cn/' : 'https://bbs.byr.cn/';
  static String get baseURL => bbsURL + 'open/';
  static String get tokenURL => bbsURL + Secrets.tokenDir;
  static bool _isAnonymous = false;
  static bool get isAnonymous => _isAnonymous;
  static String byrFaceM = NForumSpecs.bbsURL + "img/face_default_m.jpg";
  static String byrFaceF = NForumSpecs.bbsURL + "img/face_default_f.jpg";
  static const attachmentSize = 5242880;
}

enum ReferType { Reply, At }

class MessageCounts {
  final int referReplyCount;
  final int referAtCount;
  final int mailCount;

  MessageCounts({this.referReplyCount = 0, this.referAtCount = 0, this.mailCount = 0});
}

class NForumService {
  static String _currentToken;
  static String get currentToken => _currentToken;

  static String makeBBSURL(String originalUrl) {
    return originalUrl.replaceFirst(
      'static.byr',
      'bbs.byr',
    );
  }

  static String makeThreadURL(String boardName, int threadId) {
    return NForumSpecs.bbsURL + 'article/' + (boardName ?? "") + '/' + (threadId ?? "").toString();
  }

  static String makeBetURL(String bid) {
    return NForumSpecs.bbsURL + 'bet/view/' + (bid ?? "").toString();
  }

  static String makeVoteURL(String vid) {
    return NForumSpecs.bbsURL + 'vote/view/' + (vid ?? "").toString();
  }

  static String makeGetURL(String originalUrl) {
    return makeBBSURL(originalUrl) + '?oauth_token=' + currentToken;
  }

  static String makeGetAttachmentURL(String originalUrl) {
    return makeGetURL(
      makeBBSURL(originalUrl).replaceFirst('/api/', '/open/'),
    );
  }

  static Future<List<String>> getRecommendedBoards() async {
    var response;
    try {
      response = await Request.httpGet(NForumSpecs.baseURL + "recommend_boards.json", null);
    } catch (e) {
      throw e;
    }
    Map resultMap = jsonDecode(
      ascii.decode(response.bodyBytes),
    );
    if (resultMap["code"] != null) {
      throw APIException(resultMap['msg']);
    }
    var result = resultMap["recommended_boards"].cast<String>();
    if (result == null) {
      throw DataException();
    }
    return result;
  }

  static Future<WelcomeInfo> getWelcomeInfo() async {
    return Request.httpGet(NForumSpecs.baseURL + 'welcomeimg.json', null).then((response) {
      Map resultMap = jsonDecode(
        ascii.decode(response.bodyBytes),
      );
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = WelcomeInfo.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<OAuthInfo> postLoginInfo(String username, String password) async {
    var date = DateTime.now().millisecondsSinceEpoch / 1000;
    var dateStr = date.round().toString();
    var sourceStr = dateStr + Secrets.identifier;
    var digest = crypto.md5.convert(
      Utf8Encoder().convert(Secrets.clientID + Secrets.appleID + Secrets.bundleID + dateStr),
    );
    var appKey = digest.toString();
    var body = {
      'appkey': appKey,
      'source': sourceStr,
      'username': Base64Encoder().convert(username.codeUnits),
      'password': Base64Encoder().convert(password.codeUnits)
    };
    return Request.httpPost(NForumSpecs.tokenURL, body).then((response) {
      var resultMap = jsonDecode(
        ascii.decode(response.bodyBytes),
      );
      if (resultMap["code"] != null) {
        return OAuthErrorInfo.fromJson(resultMap);
      } else {
        return OAuthAccessInfo.fromJson(resultMap);
      }
    });
  }

  static Future<UserModel> getSelfUserInfo() async {
    if (currentToken == null) {
      return null;
    }
    return Request.httpGet(
      NForumSpecs.baseURL + 'user/getinfo.json',
      {
        'oauth_token': currentToken,
      },
    ).then(
      (response) {
        Map resultMap = jsonDecode(response.body);
        return UserModel.fromJson(resultMap);
      },
    );
  }

  static Future<ToptenModel> getTopten() async {
    return Request.httpGet(NForumSpecs.baseURL + 'widget/topten.json', {'oauth_token': currentToken}).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = ToptenModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<TimelineModel> getTimeline(int page) async {
    return Request.httpGet(
      NForumSpecs.baseURL + 'favorpost.json',
      {
        'oauth_token': currentToken,
        'page': page,
      },
    ).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = TimelineModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<ThreadModel> getThread(String boardName, int threadId,
      {int page, int count = PageConfig.pageItemCount, String author, int mode}) async {
    return Request.httpGet(NForumSpecs.baseURL + 'threads/' + boardName + '/' + threadId.toString() + '.json', {
      'oauth_token': currentToken,
      'page': page,
      'count': count,
      'au': author,
      "mode": mode,
    }).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = ThreadModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<BetModel> getBet(int bid) async {
    return Request.httpGet(NForumSpecs.baseURL + 'bet/' + bid.toString() + '.json', {
      'oauth_token': currentToken,
    }).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = BetModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<Map> betOn(int bid, int biid, int score) async {
    var response;
    try {
      response = await Request.httpPost(
        NForumSpecs.baseURL + 'bet/' + bid.toString() + '.json',
        {
          'oauth_token': currentToken,
          'biid': biid,
          'score': score,
        },
      );
    } catch (e) {
      throw e;
    }
    Map resultMap = jsonDecode(response.body);
    if (resultMap["code"] != null) {
      throw APIException(resultMap['msg']);
    }
    var result = resultMap;
    if (result == null) {
      throw DataException();
    }
    return result;
  }

  static Future<BetCategoriesModel> getBetCategory() async {
    return Request.httpGet(NForumSpecs.baseURL + 'bet/' + 'allCate' + '.json', {
      'oauth_token': currentToken,
    }).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = BetCategoriesModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<BetListModel> getBetList(BetAttrType betAttrType, {int cid = 0, int page = 1, int count = 20}) async {
    return Request.httpGet(NForumSpecs.baseURL + 'bet/category/' + Helper.getStrippedEnumValue(betAttrType) + '.json', {
      'oauth_token': currentToken,
      'cid': cid,
      'page': page,
      'count': count,
    }).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      resultMap['pagination'].forEach((k, v) {
        if (v is String) {
          resultMap['pagination'][k] = int.tryParse(v) ?? 0;
        }
      });
      var result = BetListModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<VoteModel> getVote(int vid) async {
    return Request.httpGet(NForumSpecs.baseURL + 'vote/' + vid.toString() + '.json', {
      'oauth_token': currentToken,
    }).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = VoteModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<Map> voteOn(int vid, List<int> viids, bool isMultiple) async {
    var param = Map<String, String>();
    for (int i = 0; i < viids.length; i++) {
      param["vote[" + i.toString() + "]"] = viids[i].toString();
    }
    param['oauth_token'] = currentToken;
    var response;
    try {
      response = await Request.httpPost(
        NForumSpecs.baseURL + 'vote/' + vid.toString() + '.json',
        isMultiple
            ? param
            : {
                'oauth_token': currentToken,
                'vote': viids[0],
              },
      );
    } catch (e) {
      throw e;
    }
    Map resultMap = jsonDecode(response.body);
    if (resultMap["code"] != null) {
      throw APIException(resultMap['msg']);
    }
    var result = resultMap;
    if (result == null) {
      throw DataException();
    }
    return result;
  }

  static Future<VoteListModel> getVoteList(VoteAttrType voteAttrType, {String u, int page = 1, int count = 20}) async {
    return Request.httpGet(
        NForumSpecs.baseURL + 'vote/category/' + Helper.getStrippedEnumValue(voteAttrType) + '.json', {
      'oauth_token': currentToken,
      'page': page,
      'count': count,
      'user': u,
    }).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      resultMap['pagination'].forEach((k, v) {
        if (v is String) {
          resultMap['pagination'][k] = int.tryParse(v) ?? 0;
        }
      });
      var result = VoteListModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<Map> postArticle(String boardName, String title, String content,
      {int reId, bool anonymousSpecial}) async {
    bool anony = anonymousSpecial ?? NForumSpecs.isAnonymous;
    var response;
    try {
      response = await Request.httpPost(
        NForumSpecs.baseURL + 'article/' + boardName + '/' + 'post' + '.json',
        {
          'oauth_token': currentToken,
          'title': title,
          'content': content,
          'reid': reId,
          "anonymous": anony ? 1 : 0,
        },
      );
    } catch (e) {
      throw e;
    }
    Map resultMap = jsonDecode(response.body);
    if (resultMap["code"] != null) {
      throw APIException(resultMap['msg']);
    }
    var result = resultMap;
    if (result == null) {
      throw DataException();
    }
    return result;
  }

  static Future<Map> updateArticle(
    String boardName,
    int id,
    String title,
    String content,
  ) async {
    var response;
    try {
      response = await Request.httpPost(
        NForumSpecs.baseURL + 'article/$boardName/update/$id.json',
        {
          'oauth_token': currentToken,
          'title': title,
          'content': content,
        },
      );
    } catch (e) {
      throw e;
    }
    Map resultMap = jsonDecode(response.body);
    if (resultMap["code"] != null) {
      throw APIException(resultMap['msg']);
    }
    var result = resultMap;
    if (result == null) {
      throw DataException();
    }
    return result;
  }

  static Future<bool> likeArticle(String boardName, int id) async {
    return Request.httpGet(NForumSpecs.baseURL + 'article/' + boardName + '/like/' + id.toString() + '.json', {
      'oauth_token': currentToken,
    }).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        return false;
      }
      return true;
    });
  }

  static Future<bool> votedownArticle(String boardName, int id) async {
    return Request.httpGet(NForumSpecs.baseURL + 'article/' + boardName + '/votedown/' + id.toString() + '.json', {
      'oauth_token': currentToken,
    }).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        return false;
      }
      return true;
    });
  }

  static Future<bool> deleteArticle(String boardName, int id) async {
    return Request.httpPost(
      NForumSpecs.baseURL + 'article/' + boardName + '/delete/' + id.toString() + '.json',
      {
        'oauth_token': currentToken,
      },
    ).then(
      (response) {
        Map resultMap = jsonDecode(response.body);
        if (resultMap["code"] != null) {
          return false;
        }
        return true;
      },
    );
  }

  static Future<BannerModel> getBanner() async {
    return Request.httpGet(NForumSpecs.baseURL + 'banner.json', {'oauth_token': currentToken}).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = BannerModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<FavBoardsModel> getFavBoards() async {
    return Request.httpGet(NForumSpecs.baseURL + 'favorite/0.json', {'oauth_token': currentToken}).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      FavBoardsModel f = FavBoardsModel.fromJson(resultMap);
      if (f == null) {
        throw DataException();
      }
      f.board.sort((a, b) => b.threadsTodayCount.compareTo(a.threadsTodayCount));
      return f;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<FavBoardsModel> addFavBoard(String boardName) async {
    return Request.httpPost(
      NForumSpecs.baseURL + 'favorite/add/0.json',
      {
        'oauth_token': currentToken,
        'name': boardName,
        'dir': 0,
      },
    ).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = FavBoardsModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<FavBoardsModel> delFavBoard(String boardName) async {
    return Request.httpPost(
      NForumSpecs.baseURL + 'favorite/delete/0.json',
      {
        'oauth_token': currentToken,
        'name': boardName,
        'dir': 0,
      },
    ).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = FavBoardsModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<BoardModel> getBoard(String boardName, {int page = 1, int count = 30, int content}) async {
    return Request.httpGet(NForumSpecs.baseURL + 'board/$boardName.json', {
      'oauth_token': currentToken,
      'page': page,
      'count': count,
      'content': content,
    }).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = BoardModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<SectionListModel> getSections() async {
    return Request.httpGet(NForumSpecs.baseURL + 'section.json', {
      'oauth_token': currentToken,
    }).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = SectionListModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<SectionModel> getSection(String sectionName) async {
    return Request.httpGet(NForumSpecs.baseURL + 'section/$sectionName.json', {
      'oauth_token': currentToken,
    }).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = SectionModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<CollectionModel> getCollection(int page, {int count = PageConfig.pageItemCount}) async {
    return Request.httpGet(NForumSpecs.baseURL + 'collection.json', {
      'oauth_token': currentToken,
      'page': page,
      'count': count,
    }).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = CollectionModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<ThreadArticleModel> addCollection(String boardName, int id) async {
    return Request.httpPost(
      NForumSpecs.baseURL + 'collection/add.json',
      {
        'oauth_token': currentToken,
        'board': boardName,
        'id': id,
      },
    ).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = ThreadArticleModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<ThreadArticleModel> removeCollection(String boardName, int id) async {
    return Request.httpPost(
      NForumSpecs.baseURL + 'collection/delete.json',
      {
        'oauth_token': currentToken,
        'board': boardName,
        'id': id,
      },
    ).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = ThreadArticleModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<ReferBoxModel> getReply(int page, {int count = PageConfig.pageItemCount}) async {
    return Request.httpGet(
      NForumSpecs.baseURL + 'refer/reply.json',
      {
        'oauth_token': currentToken,
        'page': page,
        'count': count,
      },
    ).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = ReferBoxModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<ReferBoxModel> getAt(int page, {int count = PageConfig.pageItemCount}) async {
    return Request.httpGet(
      NForumSpecs.baseURL + 'refer/at.json',
      {
        'oauth_token': currentToken,
        'page': page,
        'count': count,
      },
    ).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = ReferBoxModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<ReferModel> setReferRead(ReferType type, int index) async {
    String t = type == ReferType.At ? 'at' : 'reply';
    return Request.httpPost(
      NForumSpecs.baseURL + 'refer/$t/setRead/$index.json',
      {
        'oauth_token': currentToken,
      },
    ).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = ReferModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future setReferAllRead(ReferType type) async {
    String t = type == ReferType.At ? 'at' : 'reply';
    return Request.httpPost(
      NForumSpecs.baseURL + 'refer/$t/setRead.json',
      {
        'oauth_token': currentToken,
      },
    ).then((response) {
      return;
    });
  }

  static Future<MailBoxModel> getMailBox(int page, {int count = PageConfig.pageItemCount}) async {
    return Request.httpGet(
      NForumSpecs.baseURL + 'mail/inbox.json',
      {
        'oauth_token': currentToken,
        'page': page,
        'count': count,
      },
    ).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = MailBoxModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<MailModel> getMail(int index) async {
    return Request.httpGet(
      NForumSpecs.baseURL + 'mail/inbox/$index.json',
      {
        'oauth_token': currentToken,
      },
    ).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = MailModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<MailModel> replyMail(int index, String title, String content) async {
    return Request.httpPost(
      NForumSpecs.baseURL + 'mail/inbox/reply/$index.json',
      {'oauth_token': currentToken, 'title': title, 'content': content, 'signature': 0, 'backup': 1},
    ).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = MailModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<StatusModel> sendMail(String username, String title, String content) async {
    return Request.httpPost(
      NForumSpecs.baseURL + 'mail/send.json',
      {'oauth_token': currentToken, 'id': username, 'title': title, 'content': content, 'signature': 0, 'backup': 1},
    ).then(
      (response) {
        Map resultMap = jsonDecode(response.body);
        if (resultMap["code"] != null) {
          return StatusModel(false);
        } else {
          return StatusModel.fromJson(resultMap);
        }
      },
    );
  }

  static Future<MessageCounts> getNewMessageCount() async {
    int reply = await Request.httpGet(NForumSpecs.baseURL + 'refer/reply/info.json', {
      'oauth_token': currentToken,
    }).then((response) {
      Map resultMap = jsonDecode(response.body);
      return resultMap["new_count"] ?? 0;
    });

    int at = await Request.httpGet(NForumSpecs.baseURL + 'refer/at/info.json', {
      'oauth_token': currentToken,
    }).then((response) {
      Map resultMap = jsonDecode(response.body);
      return resultMap["new_count"] ?? 0;
    });

    int mail = await Request.httpGet(
      NForumSpecs.baseURL + 'mail/inbox.json',
      {
        'oauth_token': currentToken,
        'page': 1,
        'count': 1,
      },
    ).then(
      (response) {
        Map resultMap = jsonDecode(response.body);
        return resultMap["new_num"] ?? 0;
      },
    );
    return MessageCounts(referReplyCount: reply, referAtCount: at, mailCount: mail);
  }

  static Future<BoardSearchModel> getBoardSearch(String s) async {
    return Request.httpGet(
      NForumSpecs.baseURL + 'search/board.json',
      {
        'oauth_token': currentToken,
        'board': s,
      },
    ).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = BoardSearchModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<ThreadSearchModel> getThreadSearch({
    String board,
    int day,
    String author,
    String keyword,
    bool attach,
    int page = 1,
  }) async {
    var params = {
      'oauth_token': currentToken,
      'board': board,
      'day': day,
      'page': page,
    };
    if (author != null && author != '') {
      params['author'] = author;
    }
    if (keyword != null && keyword != '') {
      params['title1'] = keyword;
    }
    if (attach != null) {
      params['a'] = attach ? 1 : 0;
    }
    return Request.httpGet(NForumSpecs.baseURL + 'search/threads.json', params).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = ThreadSearchModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<UserModel> getUserInfo(String id) async {
    return Request.httpGet(
      NForumSpecs.baseURL + 'user/query/$id.json',
      {
        'oauth_token': currentToken,
      },
    ).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        throw APIException(resultMap['msg']);
      }
      var result = UserModel.fromJson(resultMap);
      if (result == null) {
        throw DataException();
      }
      return result;
    }).catchError((e) {
      throw e;
    });
  }

  static Future<AttachmentModel> uploadAttachment(String boardName, File attachment) async {
    try {
      return Request.httpUpload(
              NForumSpecs.baseURL + 'attachment/' + boardName + '/add.json',
              {
                'oauth_token': currentToken,
              },
              attachment)
          .then((response) {
        Map resultMap = jsonDecode(response.body);
        if (resultMap['code'] != null) {
          return AttachmentModel([], resultMap['msg'], -1);
        }
        return AttachmentModel.fromJson(resultMap);
      });
    } catch (_) {
      return AttachmentModel([], '-1', -1);
    }
  }

  static Future<AttachmentModel> uploadAttachmentToArticle(String boardName, File attachment, int id) async {
    try {
      return Request.httpUpload(
              NForumSpecs.baseURL + 'attachment/$boardName/add/$id.json',
              {
                'oauth_token': currentToken,
              },
              attachment)
          .then((response) {
        Map resultMap = jsonDecode(response.body);
        if (resultMap['code'] != null) {
          return AttachmentModel([], resultMap['msg'], -1);
        }
        return AttachmentModel.fromJson(resultMap);
      });
    } catch (_) {
      return AttachmentModel([], '-1', -1);
    }
  }

  static Future<bool> deleteAttachmentOfArticle(String boardName, int id, String name) async {
    return Request.httpPost(NForumSpecs.baseURL + 'attachment/$boardName/delete/$id.json', {
      'oauth_token': currentToken,
      'name': name,
    }).then((response) {
      Map resultMap = jsonDecode(response.body);
      if (resultMap["code"] != null) {
        return false;
      }
      return true;
    });
  }
}
