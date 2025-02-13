// Swiftified and further development by (c) 2022 and onwards The vChewing Project (MIT License).
// Was initially rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// Walking algorithm (Dijkstra) implemented by (c) 2025 and onwards The vChewing Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import AppKit
import XCTest

@testable import Megrez

final class MegrezTests: XCTestCase {
  func test01_Span() throws {
    let langModel = SimpleLM(input: strSampleData)
    var span = Megrez.SpanUnit()
    let n1 = Megrez.Node(
      keyArray: ["gao1"], spanLength: 1, unigrams: langModel.unigramsFor(keyArray: ["gao1"])
    )
    let n3 = Megrez.Node(
      keyArray: ["gao1ke1ji4"], spanLength: 3,
      unigrams: langModel.unigramsFor(keyArray: ["gao1ke1ji4"])
    )
    XCTAssertEqual(span.maxLength, 0)
    span[n1.spanLength] = n1
    XCTAssertEqual(span.maxLength, 1)
    span[n3.spanLength] = n3
    XCTAssertEqual(span.maxLength, 3)
    XCTAssertEqual(span[1], n1)
    XCTAssertEqual(span[2], nil)
    XCTAssertEqual(span[3], n3)
    span.removeAll()
    XCTAssertEqual(span.maxLength, 0)
    XCTAssertEqual(span[1], nil)
    XCTAssertEqual(span[2], nil)
    XCTAssertEqual(span[3], nil)
  }

  func test02_RankedLangModel() throws {
    class TestLM: LangModelProtocol {
      func hasUnigramsFor(keyArray: [String]) -> Bool { keyArray.joined() == "foo" }
      func unigramsFor(keyArray: [String]) -> [Megrez.Unigram] {
        keyArray.joined() == "foo"
          ? [
            .init(value: "middle", score: -5),
            .init(value: "highest", score: -2),
            .init(value: "lowest", score: -10)
          ]
          : .init()
      }
    }

    let lmRanked = Megrez.Compositor.LangModelRanked(withLM: TestLM())
    XCTAssertTrue(lmRanked.hasUnigramsFor(keyArray: ["foo"]))
    XCTAssertFalse(lmRanked.hasUnigramsFor(keyArray: ["bar"]))
    XCTAssertTrue(lmRanked.unigramsFor(keyArray: ["bar"]).isEmpty)
    let unigrams = lmRanked.unigramsFor(keyArray: ["foo"])
    XCTAssertEqual(unigrams.count, 3)
    XCTAssertEqual(unigrams[0].value, "highest")
    XCTAssertEqual(unigrams[0].score, -2)
    XCTAssertEqual(unigrams[1].value, "middle")
    XCTAssertEqual(unigrams[1].score, -5)
    XCTAssertEqual(unigrams[2].value, "lowest")
    XCTAssertEqual(unigrams[2].score, -10)
  }

  func test03_Compositor_BasicTests() throws {
    let compositor = Megrez.Compositor(with: MockLM())
    XCTAssertEqual(compositor.separator, Megrez.Compositor.theSeparator)
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertEqual(compositor.length, 0)

    compositor.insertKey("a")
    XCTAssertEqual(compositor.cursor, 1)
    XCTAssertEqual(compositor.length, 1)
    XCTAssertEqual(compositor.spans.count, 1)
    XCTAssertEqual(compositor.spans[0].maxLength, 1)
    guard let zeroNode = compositor.spans[0][1] else {
      print("fuckme")
      return
    }
    XCTAssertEqual(zeroNode.keyArray.joined(separator: compositor.separator), "a")

    compositor.dropKey(direction: .rear)
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertEqual(compositor.length, 0)
    XCTAssertEqual(compositor.spans.count, 0)
  }

  func test04_Compositor_InvalidOperations() throws {
    class TestLM: LangModelProtocol {
      func hasUnigramsFor(keyArray: [String]) -> Bool { keyArray == ["foo"] }
      func unigramsFor(keyArray: [String]) -> [Megrez.Unigram] {
        keyArray == ["foo"] ? [.init(value: "foo", score: -1)] : .init()
      }
    }

    let compositor = Megrez.Compositor(with: TestLM())
    compositor.separator = ";"
    XCTAssertFalse(compositor.insertKey("bar"))
    XCTAssertFalse(compositor.insertKey(""))
    XCTAssertFalse(compositor.insertKey(""))
    XCTAssertFalse(compositor.dropKey(direction: .rear))
    XCTAssertFalse(compositor.dropKey(direction: .front))

    XCTAssertTrue(compositor.insertKey("foo"))
    XCTAssertTrue(compositor.dropKey(direction: .rear))
    XCTAssertEqual(compositor.length, 0)
    XCTAssertTrue(compositor.insertKey("foo"))
    compositor.cursor = 0
    XCTAssertTrue(compositor.dropKey(direction: .front))
    XCTAssertEqual(compositor.length, 0)
  }

  func test05_Compositor_DeleteToTheFrontOfCursor() throws {
    let compositor = Megrez.Compositor(with: MockLM())
    compositor.insertKey("a")
    compositor.cursor = 0
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertEqual(compositor.length, 1)
    XCTAssertEqual(compositor.spans.count, 1)
    XCTAssertFalse(compositor.dropKey(direction: .rear))
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertEqual(compositor.length, 1)
    XCTAssertEqual(compositor.spans.count, 1)
    XCTAssertTrue(compositor.dropKey(direction: .front))
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertEqual(compositor.length, 0)
    XCTAssertEqual(compositor.spans.count, 0)
  }

  func test06_Compositor_MultipleSpans() throws {
    let compositor = Megrez.Compositor(with: MockLM())
    compositor.separator = ";"
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    XCTAssertEqual(compositor.cursor, 3)
    XCTAssertEqual(compositor.length, 3)
    XCTAssertEqual(compositor.spans.count, 3)
    XCTAssertEqual(compositor.spans[0].maxLength, 3)
    XCTAssertEqual(compositor.spans[0][1]?.keyArray.joined(separator: compositor.separator), "a")
    XCTAssertEqual(compositor.spans[0][2]?.keyArray.joined(separator: compositor.separator), "a;b")
    XCTAssertEqual(
      compositor.spans[0][3]?.keyArray.joined(separator: compositor.separator),
      "a;b;c"
    )
    XCTAssertEqual(compositor.spans[1].maxLength, 2)
    XCTAssertEqual(compositor.spans[1][1]?.keyArray.joined(separator: compositor.separator), "b")
    XCTAssertEqual(compositor.spans[1][2]?.keyArray.joined(separator: compositor.separator), "b;c")
    XCTAssertEqual(compositor.spans[2].maxLength, 1)
    XCTAssertEqual(compositor.spans[2][1]?.keyArray.joined(separator: compositor.separator), "c")
  }

  func test07_Compositor_SpanDeletionFromFront() throws {
    let compositor = Megrez.Compositor(with: MockLM())
    compositor.separator = ";"
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    XCTAssertFalse(compositor.dropKey(direction: .front))
    XCTAssertTrue(compositor.dropKey(direction: .rear))
    XCTAssertEqual(compositor.cursor, 2)
    XCTAssertEqual(compositor.length, 2)
    XCTAssertEqual(compositor.spans.count, 2)
    XCTAssertEqual(compositor.spans[0].maxLength, 2)
    XCTAssertEqual(compositor.spans[0][1]?.keyArray.joined(separator: compositor.separator), "a")
    XCTAssertEqual(compositor.spans[0][2]?.keyArray.joined(separator: compositor.separator), "a;b")
    XCTAssertEqual(compositor.spans[1].maxLength, 1)
    XCTAssertEqual(compositor.spans[1][1]?.keyArray.joined(separator: compositor.separator), "b")
  }

  func test08_Compositor_SpanDeletionFromMiddle() throws {
    let compositor = Megrez.Compositor(with: MockLM())
    compositor.separator = ";"
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    compositor.cursor = 2

    XCTAssertTrue(compositor.dropKey(direction: .rear))
    XCTAssertEqual(compositor.cursor, 1)
    XCTAssertEqual(compositor.length, 2)
    XCTAssertEqual(compositor.spans.count, 2)
    XCTAssertEqual(compositor.spans[0].maxLength, 2)
    XCTAssertEqual(compositor.spans[0][1]?.keyArray.joined(separator: compositor.separator), "a")
    XCTAssertEqual(compositor.spans[0][2]?.keyArray.joined(separator: compositor.separator), "a;c")
    XCTAssertEqual(compositor.spans[1].maxLength, 1)
    XCTAssertEqual(compositor.spans[1][1]?.keyArray.joined(separator: compositor.separator), "c")

    compositor.clear()
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    compositor.cursor = 1

    XCTAssertTrue(compositor.dropKey(direction: .front))
    XCTAssertEqual(compositor.cursor, 1)
    XCTAssertEqual(compositor.length, 2)
    XCTAssertEqual(compositor.spans.count, 2)
    XCTAssertEqual(compositor.spans[0].maxLength, 2)
    XCTAssertEqual(compositor.spans[0][1]?.keyArray.joined(separator: compositor.separator), "a")
    XCTAssertEqual(compositor.spans[0][2]?.keyArray.joined(separator: compositor.separator), "a;c")
    XCTAssertEqual(compositor.spans[1].maxLength, 1)
    XCTAssertEqual(compositor.spans[1][1]?.keyArray.joined(separator: compositor.separator), "c")
  }

  func test09_Compositor_SpanDeletionFromRear() throws {
    let compositor = Megrez.Compositor(with: MockLM())
    compositor.separator = ";"
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    compositor.cursor = 0

    XCTAssertFalse(compositor.dropKey(direction: .rear))
    XCTAssertTrue(compositor.dropKey(direction: .front))
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertEqual(compositor.length, 2)
    XCTAssertEqual(compositor.spans.count, 2)
    XCTAssertEqual(compositor.spans[0].maxLength, 2)
    XCTAssertEqual(compositor.spans[0][1]?.keyArray.joined(separator: compositor.separator), "b")
    XCTAssertEqual(compositor.spans[0][2]?.keyArray.joined(separator: compositor.separator), "b;c")
    XCTAssertEqual(compositor.spans[1].maxLength, 1)
    XCTAssertEqual(compositor.spans[1][1]?.keyArray.joined(separator: compositor.separator), "c")
  }

  func test10_Compositor_SpanInsertion() throws {
    let compositor = Megrez.Compositor(with: MockLM())
    compositor.separator = ";"
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    compositor.cursor = 1
    compositor.insertKey("X")

    XCTAssertEqual(compositor.cursor, 2)
    XCTAssertEqual(compositor.length, 4)
    XCTAssertEqual(compositor.spans.count, 4)
    XCTAssertEqual(compositor.spans[0].maxLength, 4)
    XCTAssertEqual(compositor.spans[0][1]?.keyArray.joined(separator: compositor.separator), "a")
    XCTAssertEqual(compositor.spans[0][2]?.keyArray.joined(separator: compositor.separator), "a;X")
    XCTAssertEqual(
      compositor.spans[0][3]?.keyArray.joined(separator: compositor.separator),
      "a;X;b"
    )
    XCTAssertEqual(
      compositor.spans[0][4]?.keyArray.joined(separator: compositor.separator),
      "a;X;b;c"
    )
    XCTAssertEqual(compositor.spans[1].maxLength, 3)
    XCTAssertEqual(compositor.spans[1][1]?.keyArray.joined(separator: compositor.separator), "X")
    XCTAssertEqual(compositor.spans[1][2]?.keyArray.joined(separator: compositor.separator), "X;b")
    XCTAssertEqual(
      compositor.spans[1][3]?.keyArray.joined(separator: compositor.separator),
      "X;b;c"
    )
    XCTAssertEqual(compositor.spans[2].maxLength, 2)
    XCTAssertEqual(compositor.spans[2][1]?.keyArray.joined(separator: compositor.separator), "b")
    XCTAssertEqual(compositor.spans[2][2]?.keyArray.joined(separator: compositor.separator), "b;c")
    XCTAssertEqual(compositor.spans[3].maxLength, 1)
    XCTAssertEqual(compositor.spans[3][1]?.keyArray.joined(separator: compositor.separator), "c")
  }

  func test11_Compositor_LongGridDeletion() throws {
    let compositor = Megrez.Compositor(with: MockLM())
    compositor.separator = ""
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    compositor.insertKey("d")
    compositor.insertKey("e")
    compositor.insertKey("f")
    compositor.insertKey("g")
    compositor.insertKey("h")
    compositor.insertKey("i")
    compositor.insertKey("j")
    compositor.insertKey("k")
    compositor.insertKey("l")
    compositor.insertKey("m")
    compositor.insertKey("n")
    compositor.cursor = 7
    XCTAssertTrue(compositor.dropKey(direction: .rear))
    XCTAssertEqual(compositor.cursor, 6)
    XCTAssertEqual(compositor.length, 13)
    XCTAssertEqual(compositor.spans.count, 13)
    XCTAssertEqual(
      compositor.spans[0][6]?.keyArray.joined(separator: compositor.separator),
      "abcdef"
    )
    XCTAssertEqual(
      compositor.spans[1][6]?.keyArray.joined(separator: compositor.separator),
      "bcdefh"
    )
    XCTAssertEqual(
      compositor.spans[1][5]?.keyArray.joined(separator: compositor.separator),
      "bcdef"
    )
    XCTAssertEqual(
      compositor.spans[2][6]?.keyArray.joined(separator: compositor.separator),
      "cdefhi"
    )
    XCTAssertEqual(
      compositor.spans[2][5]?.keyArray.joined(separator: compositor.separator),
      "cdefh"
    )
    XCTAssertEqual(
      compositor.spans[3][6]?.keyArray.joined(separator: compositor.separator),
      "defhij"
    )
    XCTAssertEqual(
      compositor.spans[4][6]?.keyArray.joined(separator: compositor.separator),
      "efhijk"
    )
    XCTAssertEqual(
      compositor.spans[5][6]?.keyArray.joined(separator: compositor.separator),
      "fhijkl"
    )
    XCTAssertEqual(
      compositor.spans[6][6]?.keyArray.joined(separator: compositor.separator),
      "hijklm"
    )
    XCTAssertEqual(
      compositor.spans[7][6]?.keyArray.joined(separator: compositor.separator),
      "ijklmn"
    )
    XCTAssertEqual(
      compositor.spans[8][5]?.keyArray.joined(separator: compositor.separator),
      "jklmn"
    )
  }

  func test12_Compositor_LongGridInsertion() throws {
    let compositor = Megrez.Compositor(with: MockLM())
    compositor.separator = ""
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    compositor.insertKey("d")
    compositor.insertKey("e")
    compositor.insertKey("f")
    compositor.insertKey("g")
    compositor.insertKey("h")
    compositor.insertKey("i")
    compositor.insertKey("j")
    compositor.insertKey("k")
    compositor.insertKey("l")
    compositor.insertKey("m")
    compositor.insertKey("n")
    compositor.cursor = 7
    compositor.insertKey("X")
    XCTAssertEqual(compositor.cursor, 8)
    XCTAssertEqual(compositor.length, 15)
    XCTAssertEqual(compositor.spans.count, 15)
    XCTAssertEqual(
      compositor.spans[0][6]?.keyArray.joined(separator: compositor.separator),
      "abcdef"
    )
    XCTAssertEqual(
      compositor.spans[1][6]?.keyArray.joined(separator: compositor.separator),
      "bcdefg"
    )
    XCTAssertEqual(
      compositor.spans[2][6]?.keyArray.joined(separator: compositor.separator),
      "cdefgX"
    )
    XCTAssertEqual(
      compositor.spans[3][6]?.keyArray.joined(separator: compositor.separator),
      "defgXh"
    )
    XCTAssertEqual(
      compositor.spans[3][5]?.keyArray.joined(separator: compositor.separator),
      "defgX"
    )
    XCTAssertEqual(
      compositor.spans[4][6]?.keyArray.joined(separator: compositor.separator),
      "efgXhi"
    )
    XCTAssertEqual(
      compositor.spans[4][5]?.keyArray.joined(separator: compositor.separator),
      "efgXh"
    )
    XCTAssertEqual(compositor.spans[4][4]?.keyArray.joined(separator: compositor.separator), "efgX")
    XCTAssertEqual(compositor.spans[4][3]?.keyArray.joined(separator: compositor.separator), "efg")
    XCTAssertEqual(
      compositor.spans[5][6]?.keyArray.joined(separator: compositor.separator),
      "fgXhij"
    )
    XCTAssertEqual(
      compositor.spans[6][6]?.keyArray.joined(separator: compositor.separator),
      "gXhijk"
    )
    XCTAssertEqual(
      compositor.spans[7][6]?.keyArray.joined(separator: compositor.separator),
      "Xhijkl"
    )
    XCTAssertEqual(
      compositor.spans[8][6]?.keyArray.joined(separator: compositor.separator),
      "hijklm"
    )
  }

  func test13_Compositor_StressBench() throws {
    NSLog("// Stress test preparation begins.")
    let compositor = Megrez.Compositor(with: SimpleLM(input: strStressData))
    (0 ..< 1919).forEach { _ in
      compositor.insertKey("yi1")
    }
    NSLog("// Stress test started.")
    let startTime = CFAbsoluteTimeGetCurrent()
    compositor.walk()
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    NSLog("// Stress test elapsed: \(timeElapsed)s.")
  }

  func test14_Compositor_WordSegmentation() throws {
    let compositor = Megrez.Compositor(with: SimpleLM(input: strSampleData, swapKeyValue: true))
    compositor.separator = ""
    "高科技公司的年終獎金".forEach { i in
      compositor.insertKey(i.description)
    }
    let result = compositor.walk()
    XCTAssertEqual(result.joinedKeys(by: ""), ["高科技", "公司", "的", "年終", "獎金"])
  }

  func test15_Compositor_InputTestAndCursorJump() throws {
    var compositor = Megrez.Compositor(with: SimpleLM(input: strSampleData))
    compositor.separator = ""
    compositor.insertKey("gao1")
    compositor.walk()
    compositor.insertKey("ji4")
    compositor.walk()
    compositor.cursor = 1
    compositor.insertKey("ke1")
    compositor.walk()
    compositor.cursor = 0
    compositor.dropKey(direction: .front)
    compositor.walk()
    compositor.insertKey("gao1")
    compositor.walk()
    compositor.cursor = compositor.length
    compositor.insertKey("gong1")
    compositor.walk()
    compositor.insertKey("si1")
    compositor.walk()
    compositor.insertKey("de5")
    compositor.walk()
    compositor.insertKey("nian2")
    compositor.walk()
    compositor.insertKey("zhong1")
    compositor.walk()
    compositor.insertKey("jiang3")
    compositor.walk()
    compositor.insertKey("jin1")
    var result = compositor.walk()
    XCTAssertEqual(result.values, ["高科技", "公司", "的", "年中", "獎金"])
    XCTAssertEqual(compositor.length, 10)
    compositor.cursor = 7
    let candidates = compositor.fetchCandidates(at: compositor.cursor).map(\.value)
    XCTAssertTrue(candidates.contains("年中"))
    XCTAssertTrue(candidates.contains("年終"))
    XCTAssertTrue(candidates.contains("中"))
    XCTAssertTrue(candidates.contains("鍾"))
    XCTAssertTrue(compositor.overrideCandidateLiteral("年終", at: 7))
    result = compositor.walk()
    XCTAssertEqual(result.values, ["高科技", "公司", "的", "年終", "獎金"])
    let candidatesBeginAt = compositor.fetchCandidates(at: 3, filter: .beginAt).map(\.value)
    let candidatesEndAt = compositor.fetchCandidates(at: 3, filter: .endAt).map(\.value)
    XCTAssertFalse(candidatesBeginAt.contains("濟公"))
    XCTAssertFalse(candidatesEndAt.contains("公司"))
    // Test cursor jump.
    compositor.cursor = 8
    XCTAssertTrue(compositor.jumpCursorBySpan(to: .rear))
    XCTAssertEqual(compositor.cursor, 6)
    XCTAssertTrue(compositor.jumpCursorBySpan(to: .rear))
    XCTAssertEqual(compositor.cursor, 5)
    XCTAssertTrue(compositor.jumpCursorBySpan(to: .rear))
    XCTAssertEqual(compositor.cursor, 3)
    XCTAssertTrue(compositor.jumpCursorBySpan(to: .rear))
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertFalse(compositor.jumpCursorBySpan(to: .rear))
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertTrue(compositor.jumpCursorBySpan(to: .front))
    XCTAssertEqual(compositor.cursor, 3)
    XCTAssertTrue(compositor.jumpCursorBySpan(to: .front))
    XCTAssertEqual(compositor.cursor, 5)
    XCTAssertTrue(compositor.jumpCursorBySpan(to: .front))
    XCTAssertEqual(compositor.cursor, 6)
    XCTAssertTrue(compositor.jumpCursorBySpan(to: .front))
    XCTAssertEqual(compositor.cursor, 8)
    XCTAssertTrue(compositor.jumpCursorBySpan(to: .front))
    XCTAssertEqual(compositor.cursor, 10)
    XCTAssertFalse(compositor.jumpCursorBySpan(to: .front))
    XCTAssertEqual(compositor.cursor, 10)
    // Test dumpDOT.
    let expectedDumpDOT =
      "digraph {\ngraph [ rankdir=LR ];\nBOS;\nBOS -> 高;\n高;\n高 -> 科;\n高 -> 科技;\nBOS -> 高科技;\n高科技;\n高科技 -> 工;\n高科技 -> 公司;\n科;\n科 -> 際;\n科 -> 濟公;\n科技;\n科技 -> 工;\n科技 -> 公司;\n際;\n際 -> 工;\n際 -> 公司;\n濟公;\n濟公 -> 斯;\n工;\n工 -> 斯;\n公司;\n公司 -> 的;\n斯;\n斯 -> 的;\n的;\n的 -> 年;\n的 -> 年終;\n年;\n年 -> 中;\n年終;\n年終 -> 獎;\n年終 -> 獎金;\n中;\n中 -> 獎;\n中 -> 獎金;\n獎;\n獎 -> 金;\n獎金;\n獎金 -> EOS;\n金;\n金 -> EOS;\nEOS;\n}\n"
    XCTAssertEqual(compositor.dumpDOT, expectedDumpDOT)
    // Extra tests example: Litch.
    compositor = Megrez.Compositor(with: SimpleLM(input: strSampleDataLitch))
    compositor.separator = ""
    compositor.clear()
    compositor.insertKey("nai3")
    compositor.insertKey("ji1")
    result = compositor.walk()
    XCTAssertEqual(result.values, ["荔枝"])
    XCTAssertTrue(compositor.overrideCandidateLiteral("雞", at: 1))
    result = compositor.walk()
    XCTAssertEqual(result.values, ["乃", "雞"])
  }

  func test16_Compositor_InputTest2() throws {
    let compositor = Megrez.Compositor(with: SimpleLM(input: strSampleData))
    compositor.separator = ""
    compositor.insertKey("gao1")
    compositor.insertKey("ke1")
    compositor.insertKey("ji4")
    var result = compositor.walk()
    XCTAssertEqual(result.values, ["高科技"])
    compositor.insertKey("gong1")
    compositor.insertKey("si1")
    result = compositor.walk()
    XCTAssertEqual(result.values, ["高科技", "公司"])
  }

  func test17_Compositor_OverrideOverlappingNodes() throws {
    let compositor = Megrez.Compositor(with: SimpleLM(input: strSampleData))
    compositor.separator = ""
    compositor.insertKey("gao1")
    compositor.insertKey("ke1")
    compositor.insertKey("ji4")
    var result = compositor.walk()
    XCTAssertEqual(result.values, ["高科技"])
    compositor.cursor = 0
    XCTAssertTrue(compositor.overrideCandidateLiteral("膏", at: compositor.cursor))
    result = compositor.walk()
    XCTAssertEqual(result.values, ["膏", "科技"])
    XCTAssertTrue(compositor.overrideCandidateLiteral("高科技", at: 1))
    result = compositor.walk()
    XCTAssertEqual(result.values, ["高科技"])
    XCTAssertTrue(compositor.overrideCandidateLiteral("膏", at: 0))
    result = compositor.walk()
    XCTAssertEqual(result.values, ["膏", "科技"])

    XCTAssertTrue(compositor.overrideCandidateLiteral("柯", at: 1))
    result = compositor.walk()
    XCTAssertEqual(result.values, ["膏", "柯", "際"])

    XCTAssertTrue(compositor.overrideCandidateLiteral("暨", at: 2))
    result = compositor.walk()
    XCTAssertEqual(result.values, ["膏", "柯", "暨"])

    XCTAssertTrue(compositor.overrideCandidateLiteral("高科技", at: 3))
    result = compositor.walk()
    XCTAssertEqual(result.values, ["高科技"])
  }

  func test18_Compositor_OverrideReset() throws {
    let compositor = Megrez.Compositor(
      with: SimpleLM(input: strSampleData + "zhong1jiang3 終講 -11.0\n" + "jiang3jin1 槳襟 -11.0\n")
    )
    compositor.separator = ""
    compositor.insertKey("nian2")
    compositor.insertKey("zhong1")
    compositor.insertKey("jiang3")
    compositor.insertKey("jin1")
    var result = compositor.walk()
    XCTAssertEqual(result.values, ["年中", "獎金"])

    XCTAssertTrue(compositor.overrideCandidateLiteral("終講", at: 1))
    result = compositor.walk()
    XCTAssertEqual(result.values, ["年", "終講", "金"])

    XCTAssertTrue(compositor.overrideCandidateLiteral("槳襟", at: 2))
    result = compositor.walk()
    XCTAssertEqual(result.values, ["年中", "槳襟"])

    XCTAssertTrue(compositor.overrideCandidateLiteral("年終", at: 0))
    result = compositor.walk()
    XCTAssertEqual(result.values, ["年終", "槳襟"])
  }

  func test19_Compositor_CandidateDisambiguation() throws {
    let compositor = Megrez.Compositor(with: SimpleLM(input: strEmojiSampleData))
    compositor.separator = ""
    compositor.insertKey("gao1")
    compositor.insertKey("re4")
    compositor.insertKey("huo3")
    compositor.insertKey("yan4")
    compositor.insertKey("wei2")
    compositor.insertKey("xian3")
    var result = compositor.walk()
    XCTAssertEqual(result.values, ["高熱", "火焰", "危險"])
    let location = 2

    XCTAssertTrue(compositor.overrideCandidate(.init(keyArray: ["huo3"], value: "🔥"), at: location))
    result = compositor.walk()
    XCTAssertEqual(result.values, ["高熱", "🔥", "焰", "危險"])

    XCTAssertTrue(compositor.overrideCandidate(
      .init(keyArray: ["huo3", "yan4"], value: "🔥"),
      at: location
    ))
    result = compositor.walk()
    XCTAssertEqual(result.values, ["高熱", "🔥", "危險"])
  }

  func test20_Compositor_UpdateUnigramData() throws {
    let theLM = SimpleLM(input: strSampleData)
    let compositor = Megrez.Compositor(with: theLM)
    compositor.separator = ""
    compositor.insertKey("nian2")
    compositor.insertKey("zhong1")
    compositor.insertKey("jiang3")
    compositor.insertKey("jin1")
    let oldResult = compositor.walk().values.joined()
    print(oldResult)
    theLM.trim(key: "nian2zhong1", value: "年中")
    compositor.update(updateExisting: true)
    let newResult = compositor.walk().values.joined()
    print(newResult)
    XCTAssertEqual([oldResult, newResult], ["年中獎金", "年終獎金"])
    compositor.cursor = 4
    compositor.dropKey(direction: .rear)
    compositor.dropKey(direction: .rear)
    theLM.trim(key: "nian2zhong1", value: "年終")
    compositor.update(updateExisting: true)
    let newResult2 = compositor.walk().values
    print(newResult2)
    XCTAssertEqual(newResult2, ["年", "中"])
  }

  func test21_Compositor_HardCopy() throws {
    let theLM = SimpleLM(input: strSampleData)
    let rawReadings = "gao1 ke1 ji4 gong1 si1 de5 nian2 zhong1 jiang3 jin1"
    let compositorA = Megrez.Compositor(with: theLM)
    rawReadings.split(separator: " ").forEach { key in
      compositorA.insertKey(key.description)
    }
    let compositorB = compositorA.copy
    let resultA = compositorA.walk()
    let resultB = compositorB.walk()
    XCTAssertEqual(resultA, resultB)
  }

  func test22_Compositor_SanitizingNodeCrossing() throws {
    let theLM = SimpleLM(input: strSampleData)
    let rawReadings = "ke1 ke1"
    let compositor = Megrez.Compositor(with: theLM)
    rawReadings.split(separator: " ").forEach { key in
      compositor.insertKey(key.description)
    }
    var a = compositor.fetchCandidates(at: 1, filter: .beginAt).map(\.keyArray.count).max() ?? 0
    var b = compositor.fetchCandidates(at: 1, filter: .endAt).map(\.keyArray.count).max() ?? 0
    var c = compositor.fetchCandidates(at: 0, filter: .beginAt).map(\.keyArray.count).max() ?? 0
    var d = compositor.fetchCandidates(at: 2, filter: .endAt).map(\.keyArray.count).max() ?? 0
    XCTAssertEqual("\(a) \(b) \(c) \(d)", "1 1 2 2")
    compositor.cursor = compositor.length
    compositor.insertKey("jin1")
    a = compositor.fetchCandidates(at: 1, filter: .beginAt).map(\.keyArray.count).max() ?? 0
    b = compositor.fetchCandidates(at: 1, filter: .endAt).map(\.keyArray.count).max() ?? 0
    c = compositor.fetchCandidates(at: 0, filter: .beginAt).map(\.keyArray.count).max() ?? 0
    d = compositor.fetchCandidates(at: 2, filter: .endAt).map(\.keyArray.count).max() ?? 0
    XCTAssertEqual("\(a) \(b) \(c) \(d)", "1 1 2 2")
  }

  func test23_Compositor_CheckGetCandidates() throws {
    let theLM = SimpleLM(input: strSampleData)
    let rawReadings = "gao1 ke1 ji4 gong1 si1 de5 nian2 zhong1 jiang3 jin1"
    let compositor = Megrez.Compositor(with: theLM)
    rawReadings.split(separator: " ").forEach { key in
      compositor.insertKey(key.description)
    }
    var stack1A = [String]()
    var stack1B = [String]()
    var stack2A = [String]()
    var stack2B = [String]()
    for i in 0 ... compositor.keys.count {
      stack1A
        .append(
          compositor.fetchCandidates(at: i, filter: .beginAt).map(\.value)
            .joined(separator: "-")
        )
      stack1B
        .append(
          compositor.fetchCandidates(at: i, filter: .endAt).map(\.value)
            .joined(separator: "-")
        )
      stack2A
        .append(
          compositor.fetchCandidatesDeprecated(at: i, filter: .beginAt).map(\.value)
            .joined(separator: "-")
        )
      stack2B
        .append(
          compositor.fetchCandidatesDeprecated(at: i, filter: .endAt).map(\.value)
            .joined(separator: "-")
        )
    }
    stack1B.removeFirst()
    stack2B.removeLast()
    XCTAssertEqual(stack1A, stack2A)
    XCTAssertEqual(stack1B, stack2B)
  }
}
