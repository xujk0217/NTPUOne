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
    var scheduleText: String? = nil
}

// ViewModel
class CourseGViewModel: ObservableObject {
    @Published var courseno: String = ""
    @Published var courseYear: String
    @Published var courseSemester: String
    @Published var courses: [CourseG] = []
    
    // 根據當前日期計算預設年份和學期
    static func getDefaultYearAndSemester() -> (year: String, semester: String) {
        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now)
        let westernYear = calendar.component(.year, from: now)
        let rocYear = westernYear - 1911
        
        // 1-7月：前一年 + 第二學期
        // 8-12月：今年 + 第一學期
        if month >= 1 && month <= 7 {
            return (year: String(rocYear - 1), semester: "2")
        } else {
            return (year: String(rocYear), semester: "1")
        }
    }
    
    init() {
        let defaults = CourseGViewModel.getDefaultYearAndSemester()
        self.courseYear = defaults.year
        self.courseSemester = defaults.semester
    }
    @Published var errorMessage: String?
    @Published var htmlString: String?
    @Published var isLoading: Bool = false

    private var cancellables = Set<AnyCancellable>()

    func fetchCourses() {
        guard !courseYear.isEmpty, !courseSemester.isEmpty else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid URL"
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
            self.courses = []
        }

        let request = CourseCatalogService.request(year: courseYear, term: courseSemester, code: courseno)

        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                return try CourseCatalogService.decode(data)
            }
            .tryMap { try CourseCatalogService.parse($0) }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                self.isLoading = false
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

}

// SwiftUI
struct CourseGetView: View {
    @State var newCourse = Course(id: "", name: "", day: "Monday", startTime: .none, timeSlot: .morning1, location: "", teacher: "", isNotification: true)
    @StateObject var viewModel = CourseGViewModel()
    
    @ObservedObject var courseData: CourseData
    
    @StateObject private var courseYearManager = CourseYearManager()
    
    @State var showingSheet = false
    
    var endTime: Course.TimeSlot = Course.TimeSlot.morning1
    
    @State var selectCourse = CourseG(courseno: "", courseName: "", teacher: "", time: "", location: "")
    
    // 動態計算年份選項：當前民國年 ± 1
    var years: [String] {
        let westernYear = Calendar.current.component(.year, from: Date())
        let rocYear = westernYear - 1911
        return [String(rocYear + 1), String(rocYear), String(rocYear - 1)]
    }
    
    let semesters = ["1", "2"]
    
    @State var isSelect = false
    
    @State var SelectCourseNo = ""
    
    @State var selectYear = "114"
    
    @State var selectSemester = "1"
    
    @Binding var isPresented: Bool

    var body: some View {
        RemoteConfigFeatureGate(feature: .courseSearch) {
        NavigationStack {
            VStack {
                List {
                    Section{
                        HStack{
                            // 使用 Picker 选择年份
                            Picker(String(localized: "select_year"), selection: $viewModel.courseYear) {
                                ForEach(years, id: \.self) { year in
                                    Text("\(year)")
                                }
                            }
                            Picker(String(localized: "select_semester"), selection: $viewModel.courseSemester) {
                                ForEach(semesters, id: \.self) { semester in
                                    Text("\(semester)")
                                }
                            }
                        }
                        HStack{
                            Text(String(localized: "enter_course_code"))
                            TextField(String(localized: "course_code_placeholder"), text: $viewModel.courseno)
                        }
                        Button(action: { viewModel.fetchCourses() }) {
                            HStack(spacing: 8) {
                                if viewModel.isLoading {
                                    ProgressView().scaleEffect(0.9)
                                }
                                Text(viewModel.isLoading ? String(localized: "searching") : String(localized: "search_course"))
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(viewModel.isLoading)

                    } header: {
                        Text(String(localized: "course_search"))
                    } footer: {
                        Text(String(localized: "skip_if_no_course_code"))
                    }
                    
                    Section{
                        if let errorMessage = viewModel.errorMessage {
                            if errorMessage == "沒有找到課程"{
                                Text(String(localized: "no_course_found"))
                                    .foregroundColor(.red)
                            }else {
                                Text(String(localized: "search_error_hint"))
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
                                            Text(String(localized: "course_code_label \(course.courseno)"))
                                            Text(String(localized: "course_name_label \(course.courseName)"))
                                            Text(String(localized: "course_teacher_label \(course.teacher)"))
                                            Text(String(localized: "course_time_label \(course.time)"))
                                            Text(String(localized: "course_location_label \(course.location)"))
                                        }
                                        Spacer()
                                        Image(systemName: SelectCourseNo == course.courseno ? "circle.circle" : "circle")
                                            .padding()
                                    }
                                    .padding()
                                    .foregroundStyle(SelectCourseNo == course.courseno ? Color.blue : Color.primary)
                                }
                            }
                        } else {
                            Text(String(localized: "no_course_queried"))
                                .foregroundColor(.gray)
                        }
                    } header: {
                        Text(String(localized: "search_result_header"))
                    } footer: {
                        Text(String(localized: "course_info_may_error"))
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
            .navigationTitle(String(localized: "course_search"))
        }
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
