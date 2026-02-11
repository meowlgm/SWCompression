// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

#if os(Linux)
    import CoreFoundation
#endif

import Foundation
import SwiftCLI

final class ShowBenchmarkCommand: Command {

    let name = "show"
    let shortDescription = "Print saved benchmarks results"

    @Key("-c", "--compare", description: "Compare with other saved benchmarks results")
    var comparePath: String?

    @Key("--self-compare", description: "Compare runs within the same file with new results identified by run UUID")
    var selfCompare: String?

    @Flag("--print-uuid", description: "Prints internal UUIDs of saved benchmark runs")
    var printUuid: Bool

    @Flag("--metadata-only", description: "Prints only metadata of saved benchmark runs")
    var metadataOnly: Bool

    @Param var path: String

    var optionGroups: [OptionGroup] {
        return [.atMostOne($comparePath, $selfCompare)]
    }

    func execute() throws {
        let newSaveFile = try SaveFile.load(from: self.path)
        var newMetadatas: [UUID: String]
        if let newUUIDString = self.selfCompare {
            guard let newUUID = UUID(uuidString: newUUIDString)
                else { swcompExit(.benchmarkBadUUID) }
            guard newSaveFile.metadatas.contains(where: { $0.key == newUUID} )
                else { swcompExit(.benchmarkNoUUID) }
            newMetadatas = [newUUID: ""]
        } else {
            newMetadatas = Dictionary(uniqueKeysWithValues: zip(newSaveFile.metadatas.keys, (1...newSaveFile.metadatas.count).map { "(\($0))" }))
            if newMetadatas.count == 1 {
                newMetadatas[newMetadatas.first!.key] = ""
            }
        }

        for (metadataUUID, index) in newMetadatas.sorted(by: { Int($0.value.dropFirst().dropLast())! < Int($1.value.dropFirst().dropLast())! }) {
            print("NEW\(index) Metadata")
            print("---------------")
            if self.printUuid {
                print("UUID: \(metadataUUID)")
            }
            newSaveFile.metadatas[metadataUUID]!.print()
        }

        var newResults = [String: [(BenchmarkResult, UUID)]]()
        for newRun in newSaveFile.runs.filter ( { (run: SaveFile.Run) in newMetadatas.keys.contains(where: { $0 == run.metadataUUID }) }) {
            newResults.merge(Dictionary(grouping: newRun.results.map { ($0, newRun.metadataUUID) }, by: { $0.0.id }),
                                  uniquingKeysWith: { $0 + $1 })
        }

        var baseResults = [String: [(BenchmarkResult, UUID)]]()
        var baseMetadatas = [UUID: String]()
        if let comparePath = comparePath {
            let baseSaveFile = try SaveFile.load(from: comparePath)

            baseMetadatas = Dictionary(uniqueKeysWithValues: zip(baseSaveFile.metadatas.keys, (1...baseSaveFile.metadatas.count).map { "(\($0))" }))
            if baseMetadatas.count == 1 {
                baseMetadatas[baseMetadatas.first!.key] = ""
            }
            for (metadataUUID, index) in baseMetadatas.sorted(by: { Int($0.value.dropFirst().dropLast())! < Int($1.value.dropFirst().dropLast())! }) {
                print("BASE\(index) Metadata")
                print("----------------")
                if self.printUuid {
                    print("UUID: \(metadataUUID)")
                }
                baseSaveFile.metadatas[metadataUUID]!.print()
            }

            for baseRun in baseSaveFile.runs {
                baseResults.merge(Dictionary(grouping: baseRun.results.map { ($0, baseRun.metadataUUID) }, by: { $0.0.id }),
                                  uniquingKeysWith: { $0 + $1 })
            }
        } else if let newUUIDString = self.selfCompare {
            guard let newUUID = UUID(uuidString: newUUIDString)
                else { swcompExit(.benchmarkBadUUID) }
            guard newSaveFile.metadatas.contains(where: { $0.key == newUUID} )
                else { swcompExit(.benchmarkNoUUID) }
            baseMetadatas = Dictionary(uniqueKeysWithValues: zip(newSaveFile.metadatas.keys.filter({ $0 != newUUID }), (1...(newSaveFile.metadatas.count - 1)).map { "(\($0))" }))
            if baseMetadatas.count == 1 {
                baseMetadatas[baseMetadatas.first!.key] = ""
            }
            for (metadataUUID, index) in baseMetadatas.sorted(by: { Int($0.value.dropFirst().dropLast())! < Int($1.value.dropFirst().dropLast())! }) {
                print("BASE\(index) Metadata")
                print("----------------")
                if self.printUuid {
                    print("UUID: \(metadataUUID)")
                }
                newSaveFile.metadatas[metadataUUID]!.print()
            }

            for baseRun in newSaveFile.runs.filter ( { (run: SaveFile.Run) in !newMetadatas.keys.contains(where: { $0 == run.metadataUUID }) }) {
                baseResults.merge(Dictionary(grouping: baseRun.results.map { ($0, baseRun.metadataUUID) }, by: { $0.0.id }),
                                  uniquingKeysWith: { $0 + $1 })
            }
        }

        if self.metadataOnly {
            return
        }

        for resultId in newResults.keys.sorted() {
            let results = newResults[resultId]!
            print()
            print("----------------")
            print()
            print("\(results[0].0.name) => \(results[0].0.input), iterations = \(results[0].0.iterCount)")
            print()
            for (result, metadataUUID) in results.sorted(by: { Int(newMetadatas[$0.1]!.dropFirst().dropLast())! < Int(newMetadatas[$1.1]!.dropFirst().dropLast())! }) {
                let benchmark = Benchmarks(rawValue: result.name)?.initialized(result.input)
                if let warmup = result.warmup {
                    print("NEW\(newMetadatas[metadataUUID]!):  average = \(benchmark.format(result.avg)), standard deviation = \(benchmark.format(result.std)), warmup = \(benchmark.format(warmup))")
                } else {
                    print("NEW\(newMetadatas[metadataUUID]!):  average = \(benchmark.format(result.avg)), standard deviation = \(benchmark.format(result.std))")
                }
                if let baseResults = baseResults[resultId] {
                    for (other, baseUUID) in baseResults.sorted(by: { Int(baseMetadatas[$0.1]!.dropFirst().dropLast())! < Int(baseMetadatas[$1.1]!.dropFirst().dropLast())! }) {
                        if let otherWarmup = other.warmup {
                            print("BASE\(baseMetadatas[baseUUID]!): average = \(benchmark.format(other.avg)), standard deviation = \(benchmark.format(other.std)), warmup = \(benchmark.format(otherWarmup))")
                        } else {
                            print("BASE\(baseMetadatas[baseUUID]!): average = \(benchmark.format(other.avg)), standard deviation = \(benchmark.format(other.std))")
                        }
                        result.printComparison(with: other)
                    }
                }
            }
        }
    }

}

fileprivate extension Optional where Wrapped == Benchmark {

    func format(_ value: Double) -> String {
        switch self {
        case .some(let benchmark):
            return benchmark.format(value)
        case .none:
            return String(value)
        }
    }

}
