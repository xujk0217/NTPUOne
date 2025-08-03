//
//  CourseGet.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/9/3.
//

import SwiftUI
import Combine
import SwiftSoup

// 数据模型
struct CourseG: Identifiable, Decodable, Equatable {
    var id: String { courseno }
    var courseno: String
    var courseName: String
    var teacher: String
    var time: String
    var location: String
}

// 视图模型 (ViewModel)
class CourseGViewModel: ObservableObject {
    @Published var courseno: String = ""
    @Published var courseYear: String = "113"
    @Published var courseSemester: String = "1"
    @Published var courses: [CourseG] = []
    @Published var errorMessage: String?
    @Published var htmlString: String?  // 用于显示原始 HTML 的属性

    private var cancellables = Set<AnyCancellable>()

    func fetchCourses() {
        guard let url = URL(string: "https://sea.cc.ntpu.edu.tw/pls/dev_stud/course_query_all.queryByKeyword") else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid URL"
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("text/html", forHTTPHeaderField: "Accept")

        let bodyData = "qYear=\(courseYear)&qTerm=\(courseSemester)&courseno=\(courseno)&cour=&teach=&week=&seq1=A&seq2=M"
        request.httpBody = bodyData.data(using: .utf8)

        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                // 将 BIG5 编码的数据转换为 UTF-8 编码
                let big5String = NSString(data: data, encoding: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue))) as String?
                
                guard let htmlString = big5String else {
                    throw URLError(.cannotDecodeContentData)
                }
                
                // 更新 htmlString 以便于在 UI 上显示原始 HTML
                DispatchQueue.main.async {
                    self.htmlString = htmlString
                }
                
                return htmlString
            }
            .tryMap { html -> [CourseG] in
                do {
                    return try self.parseHTML(html: html)
                } catch {
                    throw error
                }
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.courses = []  // 清空课程列表，确保错误消息显示
                case .finished:
                    break
                }
            }, receiveValue: { [weak self] courses in
                self?.courses = courses
                if courses.isEmpty {
                    self?.errorMessage = "沒有找到課程"
                } else {
                    self?.errorMessage = nil  // 清空错误信息
                }
            })
            .store(in: &cancellables)
    }

    // 解析HTML
    private func parseHTML(html: String) throws -> [CourseG] {
        var courses: [CourseG] = []
        let document = try SwiftSoup.parse(html)
        
        // 打印 HTML 文档内容以调试
        let body = try document.body()?.html() ?? ""
        print("HTML Body: \(body)")
        
        // 检查是否找到课程
        let courseFound = try document.select("h4").text().contains("共找到")
        
        if !courseFound {
            DispatchQueue.main.async {
                self.errorMessage = "沒有找到課程"
            }
            return []
        }
        
        let rows = try document.select("table#example tbody tr")
        if rows.isEmpty {
            DispatchQueue.main.async {
                self.errorMessage = "沒有找到課程"
            }
            return []
        }
        
        for row in rows {
            let columns = try row.select("td")
            if columns.count >= 15 { // 确保列数足够
                
                let courseno = try columns[3].text()
                
                // 提取课程名称并去除备注
                let courseNameHTML = try columns[7].html()
                let courseName = try extractCourseName(from: courseNameHTML)
                
                
                let teacher = try columns[8].text()
                
                // 提取上课时间和教室
                let timeAndLocationHTML = try columns[13].html()
                let timeAndLocation = try extractTimeAndLocation(from: timeAndLocationHTML)
                
                // 分隔上课时间和教室
                let time = timeAndLocation.time
                let location = timeAndLocation.location
                
                let course = CourseG(courseno: courseno, courseName: courseName, teacher: teacher, time: time, location: location)
                courses.append(course)
            }
        }
        
        return courses
    }
    // 提取课程名称的方法，去除备注
    private func extractCourseName(from html: String) throws -> String {
        let document = try SwiftSoup.parse(html)
        
        // 提取纯文本内容，去除所有 HTML 标签
        if let linkElement = try document.select("a").first() {
            return try linkElement.text().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 如果没有找到 <a> 标签，返回其他可能的纯文本内容
        return try document.text().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // 提取上课时间和教室的方法
    private func extractTimeAndLocation(from html: String) throws -> (time: String, location: String) {
        let document = try SwiftSoup.parse(html)
        
        // 提取纯文本内容，去除所有 HTML 标签
        let text = try document.text()
        
        // 将文本按照空格分隔，并过滤掉空白项
        let components = text.components(separatedBy: " ").filter { !$0.isEmpty }
        
        // 根据实际数据调整分隔方式，假设第一个组件是时间，第二个是地点
        let time = components.first ?? ""
        let location = components.dropFirst().joined(separator: " ")
        
        return (time: time, location: location)
    }
}

// SwiftUI视图
struct CourseGetView: View {
    @State var newCourse = Course(id: "", name: "", day: "Monday", startTime: .none, timeSlot: .morning1, location: "", teacher: "", isNotification: true)
    @StateObject var viewModel = CourseGViewModel()
    
    @ObservedObject var courseData: CourseData
    
    @ObservedObject var courseYearManager = CourseYearManager()
    
    @State var showingSheet = false
    
    var endTime: Course.TimeSlot = Course.TimeSlot.morning1
    
    @State var selectCourse = CourseG(courseno: "", courseName: "", teacher: "", time: "", location: "")
    
    var years = ["114", "113", "112"]
    
    let semesters = ["1", "2"]
    
    @State var isSelect = false
    
    @State var SelectCourseNo = ""
    
    @State var selectYear = "113"
    
    @State var selectSemester = "1"
    
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    Section{
                        HStack{
                            // 使用 Picker 选择年份
                            Picker("選擇年份", selection: $viewModel.courseYear) {
                                ForEach(years, id: \.self) { year in
                                    Text("\(year)")
                                }
                            }
                            Picker("選擇學期", selection: $viewModel.courseSemester) {
                                ForEach(semesters, id: \.self) { semester in
                                    Text("\(semester)")
                                }
                            }
                        }
                        HStack{
                            Text("輸入課程編號:")
                            TextField("如:U4001", text: $viewModel.courseno)
                        }
                        Button("查詢課程") {
                            viewModel.fetchCourses()
                        }
                    } header: {
                        Text("課程查詢")
                    } footer: {
                        Text("如不需用課程編號新增，按 Skip")
                    }
                    
                    Section{
                        if let errorMessage = viewModel.errorMessage {
                            if errorMessage == "沒有找到課程"{
                                Text(errorMessage)
                                    .foregroundColor(.red)
                            }else {
                                Text("發生錯誤，可能因搜尋數量太多或輸入格式不對，請輸入更具體的編號")
                                    .foregroundColor(.red)
                            }
                        } else if !viewModel.courses.isEmpty {
                            ForEach(viewModel.courses) { course in
                                Button {
                                    selectCourse = course
                                    SelectCourseNo = course.courseno
                                    isSelect = true
                                } label: {
                                    HStack{
                                        VStack(alignment: .leading) {
                                            Text("課程編號: \(course.courseno)")
                                            Text("課程名稱: \(course.courseName)")
                                            Text("授課教師: \(course.teacher)")
                                            Text("上課時間: \(course.time)")
                                            Text("教室位置: \(course.location)")
                                        }
                                        Spacer()
                                        Image(systemName: SelectCourseNo == course.courseno ? "circle.circle" : "circle")
                                            .padding()
                                    }
                                    .padding()
                                    .foregroundStyle(SelectCourseNo == course.courseno ? Color.blue : Color.black)
                                }
                            }
                        } else {
                            Text("未查詢課程。")
                                .foregroundColor(.gray)
                        }
                    } header: {
                        Text("搜尋結果（點選課程後按Next）")
                    } footer: {
                        Text("課程資訊可能錯誤，按Next後請再檢查一遍")
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        Text("Cancel")
                    }

                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSheet = true
                    } label: {
                        Text("Skip")
                    }

                }
                if isSelect == true{
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSheet = true
                            isSelect = false
                            setNewCourse(selectCourse)
                            
                        } label: {
                            Text("Next")
                        }

                    }
                }
            }
            .sheet(isPresented: $showingSheet, content: {
                CourseGFormView(course: $newCourse, isNewCourse: true, onSave: {
                    courseData.addCourse(newCourse)
                    showingSheet = false
                }, onCancel: {
                    showingSheet = false
                }, courseData: courseData, isShowCourseG: $isPresented, endTimeSlot: setEndTimeSLot(selectCourse))
            })
            .onAppear {
                courseYearManager.loadYear()
        }
            .navigationTitle("課程查詢")
        }
    }
    
    func setNewCourse(_ courseGet:CourseG){
        if courseGet == CourseG(courseno: "", courseName: "", teacher: "", time: "", location: ""){
            return
        }
        newCourse.name = courseGet.courseName
        newCourse.teacher = courseGet.teacher
        newCourse.location = courseGet.location
        
        // 拆分 time 字符串
        if let (day, startS) = splitTimeAndSlots(from: courseGet.time) {
            newCourse.day = day
            
            newCourse.timeSlot = startS
        }
    }
    
    func setEndTimeSLot(_ courseGet:CourseG) -> Course.TimeSlot{
        if courseGet == CourseG(courseno: "", courseName: "", teacher: "", time: "", location: ""){
            return Course.TimeSlot.morning1
        }
        // 拆分 time 字符串
        if let endSlotTime = splitTimeGetEnd(from: courseGet.time){
            return endSlotTime
        }
        return Course.TimeSlot.morning1
    }
    
    func splitTimeAndSlots(from timeString: String) -> (day: String, startS: Course.TimeSlot)? {
        // 确保字符串长度大于3，否则无法安全切割
        guard timeString.count > 3 else {
            return nil
        }
        
        // 前三个字符表示星期几，例如 "每週二"
        let dayString = String(timeString.prefix(3))
        
        var day = "Monday"
        
        switch dayString{
        case"每週一":
            day = "Monday"
        case"每週二":
            day = "Tuesday"
        case"每週三":
            day = "Wednesday"
        case"每週四":
            day = "Thursday"
        case"每週五":
            day = "Friday"
        case"每週六":
            day = "Saturday"
        default:
            day = "Monday"
        }
        
        
        // 剩下的字符表示时间段，例如 "5~6"
        let slots = String(timeString.suffix(timeString.count - 3))
        
        var startS = Course.TimeSlot.morning1
        
        if let result = splitRangeString(slots){
            switch result.0{
            case 1:
                startS = Course.TimeSlot.morning1
            case 2:
                startS = Course.TimeSlot.morning2
            case 3:
                startS = Course.TimeSlot.morning3
            case 4:
                startS = Course.TimeSlot.morning4
            case 5:
                startS = Course.TimeSlot.afternoon1
            case 6:
                startS = Course.TimeSlot.afternoon2
            case 7:
                startS = Course.TimeSlot.afternoon3
            case 8:
                startS = Course.TimeSlot.afternoon4
            case 9:
                startS = Course.TimeSlot.afternoon5
            case 10:
                startS = Course.TimeSlot.evening1
            case 11:
                startS = Course.TimeSlot.evening2
            case 12:
                startS = Course.TimeSlot.evening3
            case 13:
                startS = Course.TimeSlot.evening4
            default:
                startS = Course.TimeSlot.morning1
            }
        }
        
        return (day, startS)
    }
    
    func splitTimeGetEnd(from timeString: String) -> Course.TimeSlot? {
        guard timeString.count > 3 else {
            return Course.TimeSlot.morning1
        }
        
        let slots = String(timeString.suffix(timeString.count - 3))
        
        var endS = Course.TimeSlot.morning1
        
        if let result = splitRangeString(slots){
            switch result.1{
            case 1:
                endS = Course.TimeSlot.morning1
            case 2:
                endS = Course.TimeSlot.morning2
            case 3:
                endS = Course.TimeSlot.morning3
            case 4:
                endS = Course.TimeSlot.morning4
            case 5:
                endS = Course.TimeSlot.afternoon1
            case 6:
                endS = Course.TimeSlot.afternoon2
            case 7:
                endS = Course.TimeSlot.afternoon3
            case 8:
                endS = Course.TimeSlot.afternoon4
            case 9:
                endS = Course.TimeSlot.afternoon5
            case 10:
                endS = Course.TimeSlot.evening1
            case 11:
                endS = Course.TimeSlot.evening2
            case 12:
                endS = Course.TimeSlot.evening3
            case 13:
                endS = Course.TimeSlot.evening4
            default:
                endS = Course.TimeSlot.morning1
            }
        }
        
        return endS
    }
    
    func splitRangeString(_ rangeString: String) -> (Int, Int)? {
        // 以"~"字符分割字符串
        let components = rangeString.split(separator: "~")
        
        // 确保分割后有两个部分
        guard components.count == 2,
              let start = Int(components[0].trimmingCharacters(in: .whitespaces)),
              let end = Int(components[1].trimmingCharacters(in: .whitespaces)) else {
            return (1, 1)
        }
        
        return (start, end)
    }
}
