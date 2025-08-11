//
//  CalculatorView.swift
//  SwiftUIPlaygroundApp
//
//  Created by Minyoung Yoo on 8/10/25.
//

import SwiftUI

//MARK: Actor
actor CalculatorActor {
    private(set) var expressionArray: [String] = []
    private(set) var calculateResult: Double?
    
    enum CalculationError: Error {
        case divideByZero, firstOrLastElementNotNumeric
    }
    
    func calculate() async throws {
        //shadow copy of expressionArray
        let array = self.expressionArray
        
        //throw error if expression's first and last element is non-numeric
        guard Double(expressionArray.last ?? "") != nil &&
                Double(expressionArray.first ?? "") != nil else {
            throw CalculationError.firstOrLastElementNotNumeric
        }
        
        //check if divide by 0
        for (index, element) in expressionArray.enumerated() {
            if element == "0" && index != 0 {
                //check dividing
                if expressionArray[index - 1] == "/" {
                    throw CalculationError.divideByZero
                }
            }
        }
        
        let _ = array.compactMap { Double($0) }
        var expression: String = ""
        
        //create expression
        for (index, element) in array.enumerated() {
            if index < 1 {
                expression += element
            } else {
                expression += "\(element)"
            }
        }
        
        //calculate
        let expressionObject = NSExpression(format: expression)
        let result = expressionObject.expressionValue(with: nil, context: nil) as? Double
        
        debugPrint("The expression is \(expression)")
        await self.setResult(result)
    }
    
    func setExpressionArray(_ expressionArray: [String]) async {
        self.expressionArray = expressionArray
    }
    
    func setResult(_ result: Double?) async {
        self.calculateResult = result
    }
    
    func allClear() async {
        self.calculateResult = nil
        self.expressionArray.removeAll()
    }
}

//MARK: View
struct CalculatorView: View {
    @State private var expression: String = ""
    @State private var expressionArray: [String] = []
    @State private var currentInputNumber: Double = 0
    @State private var currentInputCharacterArray: [String] = []
    @State private var result: Double = 0
    @State private var isDecimalPointTapped: Bool = false
    
    let gridLayout: [GridItem] = Array(repeating: .init(.adaptive(minimum: 44), spacing: 16.0), count: 4)
    let actor: CalculatorActor = .init()
    var getExpression: String {
        return self.expressionArray.map { element in
            var string = ""
            switch element {
                case "*":
                    string = "×"
                case "/":
                    string = "÷"
                default:
                    string = element
            }
            return string
        }.joined()
    }
    
    //View size constants
    let standardGap: CGFloat = 16.0
    let resultFontSize: CGFloat = 64.0
    
    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .trailing) {
                Text(String(expression))
                    .frame(maxWidth: .infinity, minHeight: self.standardGap * 2, alignment: .trailing)
                    .font(.title)
                    .foregroundStyle(.secondary)
                
                Text(String(result))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .font(.system(size: resultFontSize))
                    .lineLimit(1)
                    .minimumScaleFactor(0.1)
                    .padding(.vertical)
                
                Text(String(currentInputNumber))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .font(.largeTitle)
                    .lineLimit(1)
                    .padding(.trailing, self.standardGap / 4)
            }
            .padding(.vertical)
            
            LazyVGrid(columns: gridLayout) {
                numberButton(7)
                numberButton(8)
                numberButton(9)
                symbolButton("÷")
                
                numberButton(4)
                numberButton(5)
                numberButton(6)
                symbolButton("×")
                
                numberButton(1)
                numberButton(2)
                numberButton(3)
                symbolButton("+")
                
                numberButton(0)
                functionButton(".", isDecimalPointButton: true) {
                    withAnimation(.default.speed(2)) {
                        self.isDecimalPointTapped.toggle()
                    }
                }
                .opacity(isDecimalPointTapped ? 1 : 0.5)
                functionButton("AC") {
                    await self.actor.allClear()
                    self.allClear()
                }
                functionButton("=") {
                    self.currentInputNumber = 0
                    self.currentInputCharacterArray.removeAll()
                    do {
                        await self.actor.setExpressionArray(self.expressionArray)
                        try await self.actor.calculate()
                        self.result = await actor.calculateResult ?? 0
                        self.expression = self.getExpression
                        self.expressionArray = []
                    } catch {
                        print(error)
                    }
                }
            }
        }
        .padding()
    }
}

//MARK: ViewBuilder
extension CalculatorView {
    @ViewBuilder
    func functionButton(_ letter: String, isDecimalPointButton: Bool? = nil, completion: @escaping () async -> ()) -> some View {
        Button {
            //Add expression element if button is not decimal point
            if isDecimalPointButton == nil {
                self.expressionArray.append(String(currentInputNumber))
            }
            
            Task {
                await completion()
                self.result = await self.actor.calculateResult ?? 0.0
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.8))
                    .frame(maxWidth: self.standardGap * 25, maxHeight: self.standardGap * 25)
                Text(letter).font(.title)
            }
        }
        .controlSize(.extraLarge)
        .buttonStyle(.plain)
        .clipShape(.circle)
    }
    
    @ViewBuilder
    func symbolButton(_ symbol: String) -> some View {
        Button {
            var convertedSymbol: String = ""
            switch symbol {
                case "×":
                    convertedSymbol = "*"
                case "÷":
                    convertedSymbol = "/"
                default:
                    convertedSymbol = symbol
            }
            
            self.expressionArray.append("\(currentInputNumber)")
            self.expressionArray.append(convertedSymbol)
            self.expression = self.getExpression
            
            //continue from result if exists
            if self.result > 0 {
                self.expressionArray.removeAll()
                self.expressionArray.append("\(self.result)")
                self.expressionArray.append(convertedSymbol)
                self.expression = self.getExpression
                self.currentInputNumber = self.result
                self.result = 0
            }
            
            //re-initialize number and array
            self.currentInputNumber = 0
            currentInputCharacterArray = []
            
            //continue if pre-calculated result
            
        } label: {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.8))
                    .frame(maxWidth: self.standardGap * 25, maxHeight: self.standardGap * 25)
                Text(symbol).font(.title)
            }
        }
        .controlSize(.extraLarge)
        .buttonStyle(.plain)
        .clipShape(.circle)
    }
    
    @ViewBuilder
    func numberButton(_ number: Int) -> some View {
        Button {
            if isDecimalPointTapped {
                self.currentInputCharacterArray.append(".")
                self.isDecimalPointTapped = false
            }
            self.currentInputCharacterArray.append(String("\(number)"))
            self.currentInputNumber = Double(currentInputCharacterArray.joined()) ?? 0
        } label: {
            ZStack {
                Circle()
                    .fill(Color(uiColor: .systemGray5))
                    .frame(maxWidth: self.standardGap * 25, maxHeight: self.standardGap * 25)
                Text("\(number)").font(.title)
            }
        }
        .controlSize(.extraLarge)
        .buttonStyle(.plain)
        .clipShape(.circle)
    }
}

//MARK: Function
extension CalculatorView {
    func allClear() {
        self.expression = ""
        self.expressionArray = []
        self.currentInputNumber = 0
        self.currentInputCharacterArray.removeAll()
        self.result = 0
    }
}
