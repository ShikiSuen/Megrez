// Swiftified by (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// Rebranded from (c) Lukhnos Liu's C++ library "Gramambular" (MIT License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

extension Megrez {
  /// 節锚。
  @frozen public struct NodeAnchor: CustomStringConvertible {
    /// 節點。一個節锚內不一定有節點。
    public var node: Node?
    /// 節锚所在的位置。
    public var location: Int = 0
    /// 幅位長度。
    public var spanningLength: Int = 0
    /// 累計權重。
    public var accumulatedScore: Double = 0.0
    /// 索引鍵的長度。
    public var keyLength: Int {
      node?.key.count ?? 0
    }

    /// 將當前節锚列印成一個字串。
    public var description: String {
      var stream = ""
      stream += "{@(" + String(location) + "," + String(spanningLength) + "),"
      if let node = node {
        stream += node.description
      } else {
        stream += "null"
      }
      stream += "}"
      return stream
    }

    /// 獲取平衡權重。
    public var balancedScore: Double {
      let weightedScore: Double = (Double(spanningLength) - 1) * 2
      let nodeScore: Double = node?.score ?? 0
      return weightedScore + nodeScore
    }
  }
}

// MARK: - DumpDOT-related functions.

extension Array where Element == Megrez.NodeAnchor {
  /// 將節锚陣列列印成一個字串。
  public var description: String {
    var arrOutputContent = [""]
    for anchor in self {
      arrOutputContent.append(anchor.description)
    }
    return arrOutputContent.joined(separator: "<-")
  }
}
