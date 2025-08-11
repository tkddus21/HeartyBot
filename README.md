# ddobaki_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
### 공통 주의사항

* main 브랜치를 향한 모든 커밋은 Pull Request(PR)을 통해 병합하여 충돌을 예방합니다.
* ros 코드 내부에서 상대 경로를 package_prefix를 활용해 작성하도록 합니다.

### 코드 리뷰어로서 일하기

코드 오너(owner)는 담당 프로젝트를 향한 Pull Request(PR)를 리뷰해야 하는 책임이 있으며, 짧은 코드 리뷰는 몇 시간 내에, 긴 PR은 24 영업시간 내에 응답해야 합니다. 리뷰가 24 영업시간 이상 걸릴 것 같다면 작성자에게 알려야 합니다.

### 컨트리뷰터로서 일하기

PR 작업을 구성하는 가장 중요한 원칙은 "하나의 커밋 당 하나의 논리적 변경" 입니다. 커밋 메세지는 논리적 변경에 대해 짧고 명확하게 이야기 합니다. 커밋 메세지 제일 앞에 변경이 이루어진 프로젝트명을 적습니다. (예, "robot: ...")

#### 컨트리뷰션 하는 방법

0 단계(처음이라면): 노트북 혹은 PC에 이 저장소의 로컬 버전을 준비하세요.
* 이 저장소를 clone 합니다.
  * `git clone "https://github.com/chanho-krri/savesim`
  * `cd savesim`

1 단계: 패치를 작업할 브랜치를 만들고 개발을 진행합니다.
* 브랜치를 생성합니다.
  * `git checkout main`
  * `git checkout -b "<your-branch-name>"`
* 개발을 진행합니다.

2 단계: add, commit, push.
* 빌드와 테스트를 거친 후, 커밋을 생성합니다.
  * `git add <added/modified-files>`
  * `git commit -m "<commit-message>"`
* Github 저장소에 push 합니다.
  * `git push origin "<your-branch-name>"`
* Github 저장소의 웹 페이지에 접속하여 pull request를 생성합니다. 병합을 시킬 대상은 (chanho-krri/main 브랜치이며, maintainer의 수정을 허용해주세요)

3 단계: 코드 리뷰 수정사항 반영
* PR을 보냈던 <your-branch-name>에서 작업해야 함에 주의하세요.
  * `git checkout <your-branch-name>`
* 수정을 진행합니다.
* 빌드와 테스트를 거친 후, 커밋을 생성합니다.
  * `git add <added/modified-files>`
  * `git commit -m "<commit-message-2>"`
* Github 저장소에 push 합니다.
  * `git push origin "<your-branch-name>"`

4 단계: 내 로컬 버전 코드 최신화
* 내 PC에 있는 로컬 버전의 main 브랜치를 Github 저장소의 main 브랜치와 sync를 맞춥니다.
  * `git checkout main`
  * `git pull origin main`
* 내 PC와 Github 저장소에 있는 branch를 각각 삭제합니다.
  * `git branch -d <your-branch-name`
  * `git push origin :<your-branch-name>`
