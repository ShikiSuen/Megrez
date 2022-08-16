// Swiftified by (c) 2022 and onwards The vChewing Project (MIT License).
// Rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

extension Megrez.Compositor {
  /// 一個節點由這些內容組成：幅位長度、索引鍵、以及一組單元圖。幅位長度就是指這個
  /// 節點在組字器內橫跨了多少個字長。組字器負責構築自身的節點。對於由多個漢字組成
  /// 的詞，組字器會將多個讀音索引鍵合併為一個讀音索引鍵、據此向語言模組請求對應的
  /// 單元圖結果陣列。舉例說，如果一個詞有兩個漢字組成的話，那麼讀音也是有兩個、其
  /// 索引鍵值也是由兩個讀音組成的，那麼這個節點的幅位長度就是 2。
  public class Node: Equatable, Hashable {
    /// 三種不同的針對一個節點的覆寫行為。
    /// - withNoOverrides: 無覆寫行為。
    /// - withTopUnigramScore: 使用指定的單元圖資料值來覆寫該節點，但卻使用
    /// 當前狀態下權重最高的單元圖的權重數值。打比方說，如果該節點內的單元圖陣列是
    ///  [("a", -114), ("b", -514), ("c", -1919)] 的話，指定該覆寫行為則會導致該節
    ///  點返回的結果為 ("c", -114)。該覆寫行為多用於諸如使用者半衰記憶模組的建議
    ///  行為。被覆寫的這個節點的狀態可能不會再被爬軌行為擅自改回。該覆寫行為無法
    ///  防止其它節點被爬軌函式所支配。這種情況下就需要用到 kOverridingScore
    /// - withHighScore: 將該節點權重覆寫為 kOverridingScore，使其被爬軌函式所青睞。
    public enum OverrideType: Int {
      case withNoOverrides = 0
      case withTopUnigramScore = 1
      case withHighScore = 2
    }

    /// 一個用以覆寫權重的數值。該數值之高足以改變爬軌函式對該節點的讀取結果。這裡用
    /// 「0」可能看似足夠了，但仍會使得該節點的覆寫狀態有被爬軌函式忽視的可能。比方說
    /// 要針對索引鍵「a b c」複寫的資料值為「A B C」，使用大寫資料值來覆寫節點。這時，
    /// 如果這個獨立的 c 有一個可以拮抗權重的詞「bc」的話，可能就會導致爬軌函式的算法
    /// 找出「A->bc」的爬軌途徑（尤其是當 A 和 B 使用「0」作為複寫數值的情況下）。這樣
    /// 一來，「A-B」就不一定始終會是爬軌函式的青睞結果了。所以，這裡一定要用大於 0 的
    /// 數（比如野獸常數），以讓「c」更容易單獨被選中。
    public static let kOverridingScore: Double = 114_514

    private(set) var key: String
    private(set) var keyArray: [String]
    private(set) var spanLength: Int
    private(set) var unigrams: [Megrez.Unigram]
    private(set) var currentUnigramIndex: Int = 0 {
      didSet { currentUnigramIndex = min(max(0, currentUnigramIndex), unigrams.count - 1) }
    }

    public var currentPair: Megrez.Compositor.Candidate { .init(key: key, value: value) }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(key)
      hasher.combine(spanLength)
      hasher.combine(unigrams)
      hasher.combine(currentUnigramIndex)
      hasher.combine(spanLength)
      hasher.combine(overrideType)
    }

    private(set) var overrideType: Node.OverrideType

    public static func == (lhs: Node, rhs: Node) -> Bool {
      lhs.key == rhs.key && lhs.spanLength == rhs.spanLength
        && lhs.unigrams == rhs.unigrams && lhs.overrideType == rhs.overrideType
    }

    public init(
      keyArray: [String] = [], spanLength: Int = 0, unigrams: [Megrez.Unigram] = [], keySeparator: String = ""
    ) {
      key = keyArray.joined(separator: keySeparator)
      self.keyArray = keyArray
      self.spanLength = spanLength
      self.unigrams = unigrams
      overrideType = .withNoOverrides
    }

    /// 給出目前的最高權重單元圖。該結果可能會受節點覆寫狀態所影響。
    /// - Returns: 目前的最高權重單元圖。該結果可能會受節點覆寫狀態所影響。
    public var currentUnigram: Megrez.Unigram {
      unigrams.isEmpty ? .init() : unigrams[currentUnigramIndex]
    }

    public var value: String { currentUnigram.value }

    public var score: Double {
      guard !unigrams.isEmpty else { return 0 }
      switch overrideType {
        case .withHighScore: return Megrez.Compositor.Node.kOverridingScore
        case .withTopUnigramScore: return unigrams[0].score
        default: return currentUnigram.score
      }
    }

    public var isOverriden: Bool {
      overrideType != .withNoOverrides
    }

    public func reset() {
      currentUnigramIndex = 0
      overrideType = .withNoOverrides
    }

    public func selectOverrideUnigram(value: String, type: Node.OverrideType) -> Bool {
      guard type != .withNoOverrides else {
        return false
      }
      for (i, gram) in unigrams.enumerated() {
        if value != gram.value { continue }
        currentUnigramIndex = i
        overrideType = type
        return true
      }
      return false
    }
  }
}

extension Megrez.Compositor {
  /// 節錨。
  ///
  /// 在 Gramambular 當中又被稱為「NodeInSpan」。
  public struct NodeAnchor: Hashable {
    let node: Megrez.Compositor.Node
    let spanIndex: Int  // 幅位座標
    var spanLength: Int { node.spanLength }
    var unigrams: [Megrez.Unigram] { node.unigrams }
    var key: String { node.key }
    var value: String { node.value }

    /// 將該節錨雜湊化。
    public func hash(into hasher: inout Hasher) {
      hasher.combine(node)
      hasher.combine(spanIndex)
    }
  }
}

// MARK: - Array Extensions.

extension Array where Element == Megrez.Compositor.Node {
  /// 從一個節點陣列當中取出目前的自動選字字串陣列。
  public var values: [String] { map(\.value) }

  /// 從一個節點陣列當中取出目前的索引鍵陣列。
  public var keys: [String] { map(\.key) }

  /// 在陣列內以給定游標位置找出對應的節點。
  /// - Parameters:
  ///   - cursor: 給定游標位置。
  ///   - outCursorPastNode: 找出的節點的前端位置。
  /// - Returns: 查找結果。
  public func findNode(at cursor: Int, target outCursorPastNode: inout Int) -> Megrez.Compositor.Node? {
    guard !isEmpty else { return nil }
    let cursor = Swift.max(0, Swift.min(cursor, keys.count))

    if cursor == 0, let theFirst = first {
      outCursorPastNode = theFirst.spanLength
      return theFirst
    }

    // 同時應對「游標在右端」與「游標離右端還差一個位置」的情形。
    if cursor >= keys.count - 1, let theLast = last {
      outCursorPastNode = keys.count
      return theLast
    }

    var accumulated = 0
    for neta in self {
      accumulated += neta.spanLength
      if accumulated > cursor {
        outCursorPastNode = accumulated
        return neta
      }
    }

    // 下述情形本不應該出現。
    return nil
  }

  /// 在陣列內以給定游標位置找出對應的節點。
  /// - Parameter cursor: 給定游標位置。
  /// - Returns: 查找結果。
  public func findNode(at cursor: Int) -> Megrez.Compositor.Node? {
    var useless = 0
    return findNode(at: cursor, target: &useless)
  }
}
