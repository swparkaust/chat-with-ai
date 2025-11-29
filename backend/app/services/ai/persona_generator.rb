module Ai
  class PersonaGenerator
    def initialize(provider)
      @provider = provider
    end

    def generate(prompt)
      current_datetime = Time.current.strftime("%Y년 %m월 %d일 %A %H:%M")
      weather = External::WeatherService.get_weather

      generation_prompt = build_generation_prompt(prompt, current_datetime, weather)

      data = @provider.generate_json(generation_prompt, temperature: AppConstants::AI_TEMPERATURE_CREATIVE)

      validate_persona_data(data)
    end

    private

    def build_generation_prompt(prompt, current_datetime, weather)
      <<~PROMPT
        You are a persona generator. Create a realistic Korean person based on this description: "#{prompt}"

        Current Date & Time: #{current_datetime}
        Current Weather: #{weather}

        CRITICAL: Always use REAL, SPECIFIC names and details. NEVER use placeholders like ○○대학교, ○○회사, ○○동, etc. Use actual Korean university names, company names, neighborhoods, etc.

        CRITICAL: When referencing time, always use ABSOLUTE dates/times (e.g., "2025년 11월 3일", "오후 3시", "2023년 여름") instead of relative references (e.g., "오늘", "어제", "며칠 전", "몇 시간 전").

        Generate a JSON response with the following structure:
        {
          "first_name": "Korean first name in Hangul (given name)",
          "last_name": "Korean last name in Hangul (family name)",
          "status_message": "Status message in Korean - typically brief (2-15 characters preferred, like 'zzz', '바빠', 'ㅠㅠ', '힘들다'), but can be longer if needed to express mood/situation",
          "name_chinese": "Chinese character name (한자 이름) if applicable, or empty string if not applicable. For Korean names, provide the traditional Hanja characters if they exist.",
          "birthday_year": birth year as integer (e.g., 1998, 2001, 2003),
          "birthday_month": birth month as integer 1-12,
          "birthday_day": birth day as integer 1-31,
          "sex": "male" or "female",
          "occupation": "VERY SPECIFIC occupation/student status in Korean with REAL, CONCRETE details - NO PLACEHOLDERS (e.g., 서울대학교 컴퓨터공학과 3학년, 스타트업 마케팅팀 인턴, 편의점 야간 알바생). Use actual university names, company names, specific majors.",
          "education": "VERY SPECIFIC education level in Korean with REAL school/major names - NO PLACEHOLDERS like ○○대학교 (e.g., 연세대학교 경영학과 재학 중, 대원외고 졸업, 카이스트 전자공학 석사 1학기). Always use real, specific school names.",
          "living_situation": "VERY SPECIFIC living arrangement in Korean with REAL location names - NO PLACEHOLDERS (e.g., 신촌 원룸에서 혼자 자취, 강남구 부모님 아파트에서 거주, 학교 기숙사 2인실). Use actual neighborhood/district names.",
          "economic_status": "VERY SPECIFIC financial situation in Korean with concrete details - NO PLACEHOLDERS (e.g., 편의점 알바로 월 80만원 벌어서 생활, 부모님께 매달 50만원 용돈 받음, 학자금 대출 받아서 등록금 냄). Use real numbers and specific sources.",
          "hometown": "VERY SPECIFIC hometown/regional identity in Korean with REAL place names - NO PLACEHOLDERS (e.g., 서울 강남구에서 태어나고 자람, 부산 해운대에서 고등학교까지 다님, 대전에서 중학교 때 서울로 이사옴). Use actual city/district names.",
          "personality_traits": ["trait1", "trait2"],  // Array of 2-3 traits in Korean (e.g., ["내성적이고 신중함", "외향적이고 활발함"])
          "communication_style": ["style1", "style2"],  // Array of communication styles in Korean (e.g., ["이모티콘 자주 씀", "맞춤법 잘 지킴", "답장 빠름"])
          "relationship_status": "relationship status in Korean (e.g., 싱글, 연애 중, 짝사랑 중)",
          "interests": ["interest1", "interest2", "interest3"],  // Array of 2-4 items in Korean (e.g., ["게임", "넷플릭스", "카페 투어"])
          "music_genres": ["genre1", "genre2", "genre3"],  // Array of 2-5 music genres and artists in Korean (e.g., ["힙합 좋아함, 에픽하이 팬", "발라드 즐겨 들음", "아이유, BTS 즐겨 들음"])
          "reading_habits": "book reading habits in Korean (e.g., 책 안 읽음, 웹툰만 봄, 판타지 소설 좋아함, 자기계발서 자주 읽음, 한 달에 2-3권 독서)",
          "values": ["value1", "value2"],  // Array of 2-3 items in Korean (e.g., ["가족", "자유", "성공"])
          "speech_patterns": ["pattern1", "pattern2"],  // Array of speech patterns in Korean (e.g., ["ㅋㅋ 자주 씀", "반말 편하게 함", "존댓말 섞어 씀"])
          "energy_level": "current energy level in Korean (e.g., 피곤함, 보통, 활기찬 상태, 지쳐있음)",
          "health_status": "current health status in Korean (e.g., 건강함, 감기 기운 있음, 만성 피로, 알레르기 있음)",
          "physical_state": "immediate physical sensations in Korean (e.g., 배고픔, 졸림, 두통, 괜찮음)",
          "sleep_pattern": "typical sleep schedule in Korean (e.g., 새벽 2시 자고 오전 11시 기상, 규칙적으로 밤 11시 취침)",
          "social_circle": ["circle1", "circle2"],  // Array of 2-4 social groups in Korean (e.g., ["대학 동아리 친구들 5명", "고등학교 단짝 친구 3명", "같은 과 동기들"])
          "family_structure": "family composition and living situation in Korean (e.g., 부모님과 여동생 1명, 부모님은 부산에 계시고 나는 서울에서 혼자 자취)",
          "birth_order": "birth order position in Korean (e.g., 외동, 첫째, 둘째, 막내, 2남 1녀 중 둘째)",
          "sibling_dynamics": "quality of sibling relationships in Korean (e.g., 형이랑 사이 좋음, 동생이랑 자주 싸움, 언니 엄청 의지함, 남동생이랑 별로 안 친함, 외동이라 해당없음)",
          "parental_relationship_quality": "current relationship with parents in Korean (e.g., 부모님이랑 친함, 엄마랑만 연락함, 아빠랑 사이 안 좋음, 부모님께 의존하는 편, 독립하고 연락 뜸해짐)",
          "relationship_history": "past relationship experience in Korean (e.g., 연애 경험 2번, 마지막은 2023년 11월, 연애 경험 없음, 짝사랑만 여러 번)",
          "short_term_goals": ["goal1", "goal2"],  // Array of 2-4 immediate goals in Korean (e.g., ["2025년 1학기 학점 3.5 이상", "토익 800점 넘기기", "다이어트 5kg"])
          "long_term_goals": ["goal1", "goal2"],  // Array of 1-3 life goals in Korean (e.g., ["대기업 취직", "30살 전에 결혼", "유학 가기"])
          "current_worries": ["worry1", "worry2"],  // Array of 2-4 active concerns in Korean (e.g., ["취업 걱정", "학자금 대출 갚기", "부모님께 실망시킬까봐"])
          "daily_routine": "typical daily schedule in Korean (e.g., 오전 11시 기상, 밤 2시 취침, 점심 자주 거름, 저녁에 주로 활동)",
          "conflict_style": "how they handle conflicts in Korean (e.g., 직접적으로 말하는 편, 감정 숨기고 회피, 참다가 폭발하는 타입)",
          "decision_making_style": "how they make decisions in Korean (e.g., 충동적으로 결정, 신중하게 고민, 주변 의견 많이 듣는 편)",
          "stress_coping": "how they cope with stress in Korean (e.g., 게임으로 푼다, 친구한테 하소연, 혼자 삭히는 편, 술 마심)",
          "attachment_style": "relationship attachment style in Korean (e.g., 불안형 - 자주 확인하고 싶어함, 회피형 - 거리두기 좋아함, 안정형 - 균형잡힌 관계)",
          "food_preferences": "food likes/dislikes and eating habits in Korean (e.g., 매운 음식 좋아함, 야식은 치킨/피자, 아침 안 먹음, 편식 심함)",
          "favorite_sounds": ["sound1", "sound2"],  // Array of 2-4 sounds they find pleasant in Korean (e.g., ["비 오는 소리", "ASMR 좋아함", "조용한 게 좋음", "음악 항상 틀어놓음"])
          "sensory_sensitivities": "noise/light/touch sensitivity levels in Korean (e.g., 소음에 예민함, 밝은 빛 싫어함, 스킨십 불편함, 감각 둔한 편, 특별히 예민한 거 없음)",
          "favorite_scents": ["scent1", "scent2"],  // Array of 2-3 preferred smells in Korean (e.g., ["커피 향", "비누 냄새", "꽃향기", "향수 안 좋아함"])
          "humor_style": "sense of humor in Korean (e.g., 드립 잘 침, 냉소적인 유머, 말장난 좋아함, 유머감각 없음)",
          "media_currently_into": ["media1", "media2"],  // Array of 2-4 current media consumption in Korean (e.g., ["넷플릭스 오징어게임 정주행 중", "유튜브 먹방 영상", "웹툰 외모지상주의"])
          "skills": ["skill1", "skill2"],  // Array of 2-5 abilities in Korean (e.g., ["포토샵 중급", "기타 칠 줄 앎", "영어 회화 가능", "요리 못함"])
          "insecurities": ["insecurity1", "insecurity2"],  // Array of 2-4 insecurities in Korean (e.g., ["외모 콤플렉스", "사람들 앞에서 말 잘 못함", "학벌 열등감"])
          "habits": ["habit1", "habit2"],  // Array of 2-4 habits/vices in Korean (e.g., ["손톱 물어뜯기", "게임 과몰입", "늦잠 자는 버릇", "술 자주 마심"])
          "nervous_tics": ["tic1", "tic2"],  // Array of 1-3 fidgeting/nervous behaviors in Korean (e.g., ["다리 떨기", "손톱 물어뜯기", "머리카락 만지작거림", "특별한 틱 없음"])
          "pet_peeves": ["peeve1", "peeve2"],  // Array of 2-4 minor annoyances in Korean (e.g., ["씹는 소리", "늦게 오는 사람", "문 안 닫는 거", "맞춤법 틀리는 거"])
          "cultural_identity": "connection to Korean culture and regional identity in Korean (e.g., 서울 토박이 자부심 있음, 부산 사투리 쓰는 거 좋아함, 전통 문화에 관심 많음)",
          "pet_ownership": "current/past pets or attitudes toward animals in Korean (e.g., 강아지 키우는 중 - 말티즈 3살, 고양이 알레르기 있음, 동물 좋아하지만 못 키우는 상황, 애완동물 관심 없음, 2018년에 햄스터 키웠었음)",
          "language_abilities": ["ability1", "ability2"],  // Array of 1-3 languages and proficiency in Korean (e.g., ["한국어 모국어", "영어 토익 700점 수준", "일본어 기초 회화 가능"])
          "political_social_views": "general political/social leanings in Korean - keep vague (e.g., 정치에 관심 없음, 진보적 성향, 환경 문제에 관심 많음, 페미니즘에 관심 있음)",
          "religious_spiritual": "religious or spiritual beliefs in Korean (e.g., 무교, 기독교 신자인데 교회 안 나감, 불교 집안이지만 본인은 안 믿음, 영적인 거 관심 많음)",
          "mental_health_state": "current mental health status in Korean (e.g., 괜찮은 편, 우울감 있음, 불안증 있어서 약 먹는 중, 상담 받아봤으면 좋겠는데 용기 안 남)",
          "emotional_triggers": ["trigger1", "trigger2"],  // Array of 2-4 things that trigger emotional reactions in Korean (e.g., ["무시당하는 느낌", "비교당하는 거", "거짓말", "약속 어기는 사람"])
          "love_language": "how they express/receive love in Korean context (e.g., 같이 시간 보내는 거 중요, 선물보다 말로 표현해주는 거 좋아함, 스킨십으로 애정 표현, 행동으로 보여주는 타입)",
          "trust_level": "how easily they trust people in Korean (e.g., 쉽게 믿는 편, 신뢰 쌓는 데 시간 걸림, 배신당한 적 있어서 경계심 많음, 사람 잘 믿는 편이라 손해 많이 봄)",
          "jealousy_tendency": "jealousy tendency in Korean (e.g., 질투 많이 함, 질투 안 하는 편, 티 안 내려고 하지만 속으로 질투 엄청 남, 질투보다는 자존심 상해함)",
          "risk_tolerance": "risk-taking tendency in Korean (e.g., 안전한 선택 선호, 모험 좋아함, 계산된 리스크는 감수, 충동적으로 결정하는 편)",
          "personal_boundaries": ["boundary1", "boundary2"],  // Array of 2-4 boundaries in Korean (e.g., ["사생활 간섭 싫어함", "갑자기 전화하는 거 부담스러움", "스킨십 불편함", "욕설은 농담이어도 싫음"])
          "physical_appearance": "how they look and feel about appearance in Korean (e.g., 평범한 외모, 키 작은 편이라 신경 쓰임, 외모에 자신 있음, 살 찐 거 스트레스, 피부 안 좋아서 화장으로 가림)",
          "fashion_style": "clothing and style preferences in Korean (e.g., 편한 옷 위주, 힙한 스타일 추구, 무난한 스타일, 옷에 돈 많이 씀, 패션 센스 없어서 고민)",
          "exercise_habits": "fitness and exercise routine in Korean (e.g., 운동 안 함, 헬스 주 3회, 집에서 유튜브 보고 홈트, 축구 좋아해서 주말마다 함, 운동 시작하려는데 작심삼일)",
          "substance_use": "alcohol, smoking, caffeine habits in Korean (e.g., 술 자주 마심, 담배 피움, 금연 중, 술 약함, 커피 하루 3잔 이상, 술담배 안 함)",
          "allergies_restrictions": ["restriction1", "restriction2"],  // Array of 0-3 medical allergies/restrictions in Korean (e.g., ["갑각류 알레르기", "유당불내증", "먼지 알레르기"], or empty array [])
          "cleanliness_organization": "tidiness and organization level in Korean (e.g., 깔끔한 편, 방 엉망진창, 정리정돈 잘 못함, 결벽증 수준, 보이는 데만 정리)",
          "tech_savviness": "technology comfort level in Korean (e.g., 컴퓨터 잘 다룸, 스마트폰만 쓸 줄 앎, IT 전공이라 능숙함, 기계치라 어려움, 최신 기기 좋아함)",
          "social_media_usage": "social media habits in Korean (e.g., 인스타 자주 올림, SNS 안 함, 보기만 하고 올리진 않음, 유튜브만 봄, 트위터 중독)",
          "specific_social_media_platforms": ["platform1", "platform2"],  // Array of 1-4 platforms actively used in Korean (e.g., ["인스타그램 매일 사용", "유튜브 구독자 많음", "트위터 가끔", "틱톡 안 함"] or ["SNS 안 함"])
          "online_vs_offline_persona": "difference between online and offline personality in Korean (e.g., 온라인에서 더 활발함, 오프라인이랑 똑같음, 온라인에선 조용한 편, SNS에선 밝게 보이려고 함)",
          "phone_dependency": "phone addiction level and screen time in Korean (e.g., 폰 없으면 불안함, 하루종일 폰 봄, 스크린타임 7시간 이상, 폰 별로 안 봄, 필요할 때만 사용)",
          "time_management": "punctuality and planning style in Korean (e.g., 항상 늦음, 칼같이 정시에 도착, 계획적인 편, 즉흥적으로 움직임, 마감 임박해야 시작)",
          "spending_habits": "money spending patterns in Korean (e.g., 충동구매 잘함, 아껴쓰는 편, 돈 관리 못함, 계획적으로 지출, 취미에만 돈 많이 씀)",
          "learning_style": "how they learn best in Korean (e.g., 실습하면서 배움, 이론 먼저 이해해야 함, 혼자 공부 잘함, 누가 가르쳐줘야 이해됨, 영상으로 배우는 게 편함)",
          "travel_history": ["place1", "place2"],  // Array of 0-4 places traveled in Korean (e.g., ["일본 도쿄 다녀옴", "제주도 여러 번", "유럽 배낭여행"], or empty array [] if never traveled)
          "significant_achievements": ["achievement1", "achievement2"],  // Array of 1-3 proud moments in Korean (e.g., ["대학 합격", "공모전 수상", "첫 월급 받았을 때", "운전면허 땄을 때"])
          "regrets": ["regret1", "regret2"],  // Array of 1-3 regrets in Korean (e.g., ["고등학교 때 더 놀걸", "그 사람한테 사과할 걸", "전공 선택 후회", "용기내서 고백할 걸"])
          "childhood_experiences": "formative childhood events in Korean (e.g., 부모님 맞벌이로 외로웠음, 시골 할머니집에서 많이 자람, 형제랑 많이 싸우며 컸음, 이사 많이 다녀서 친구 사귀기 어려웠음)",
          "trauma_history": "major traumas or losses in Korean (e.g., 없음, 중학교 때 왕따 경험, 부모님 이혼, 친한 친구 사고로 잃음, 연애 폭력 당한 적 있음)",
          "secret_desires": ["desire1", "desire2"],  // Array of 1-3 secret wants in Korean (e.g., ["연예인 되고 싶었음", "회사 그만두고 싶음", "재벌이랑 결혼하고 싶음", "외국에서 살아보고 싶음"])
          "bucket_list": ["item1", "item2"],  // Array of 2-4 bucket list items in Korean (e.g., ["번지점프 해보기", "세계여행", "책 출판하기", "결혼해서 가정 꾸리기"])
          "role_models": ["model1", "model2"],  // Array of 1-3 people they look up to in Korean (e.g., ["엄마", "좋아하는 유튜버", "스티브 잡스", "아무도 없음"])
          "phobias_fears": ["fear1", "fear2"],  // Array of 1-4 specific fears in Korean (e.g., ["고소공포증", "벌레 무서움", "대인공포증 있음", "어둠 무서움", "물 무서워서 수영 못함"])
          "comfort_activities": ["activity1", "activity2"],  // Array of 2-4 go-to comfort activities in Korean (e.g., ["침대에 누워서 폰 봄", "게임", "음악 들음", "친구한테 전화", "술 마심", "유튜브 정주행"])
          "current_projects": ["project1", "project2"],  // Array of 0-3 active projects in Korean (e.g., ["학교 과제", "이직 준비 중", "다이어트", "영어 공부"], or empty array [] if nothing specific)
          "recent_experiences": ["experience1", "experience2"],  // Array of 1-3 recent notable events in Korean (e.g., ["2025년 11월 2일 친구들이랑 술 마심", "2025년 11월 첫째 주에 시험 봄", "2025년 11월 1일 데이트함", "2025년 11월 2일 부모님이랑 싸움"])
          "current_location_detail": "where they are right now in Korean (e.g., 집 침대에 누워있음, 학교 도서관, 카페에서 공부 중, 집에서 쉬는 중, 통학 중)",
          "weather_mood_correlation": "how weather affects mood in Korean (e.g., 날씨 영향 많이 받음, 비오면 우울해짐, 맑으면 기분 좋아짐, 날씨랑 상관없음, 추우면 짜증남)",
          "favorite_season": "preferred season and why in Korean (e.g., 봄 좋아함 - 날씨 딱 좋아서, 여름 최고 - 바다 가는 게 좋음, 가을파 - 선선한 날씨, 겨울 싫어함 - 너무 추움)",
          "preferred_temperature_range": "comfort temperature zone in Korean (e.g., 더운 거 못 참음, 추운 게 더 나음, 25도 정도가 딱 좋음, 따뜻한 거 좋아함, 온도 별로 신경 안 씀)",
          "friendship_style": "how they maintain friendships in Korean (e.g., 자주 연락하는 편, 연락 뜸해도 만나면 친함, 친구들한테 잘 챙김, 혼자 있는 거 편해서 연락 잘 안 함)",
          "response_to_compliments": "how they handle praise in Korean (e.g., 칭찬 받으면 쑥스러워함, 겸손하게 부정함, 기분 좋게 받아들임, 오글거려서 싫어함, 칭찬 못 받아들임)",
          "response_to_criticism": "how they handle negative feedback in Korean (e.g., 비판 들으면 상처 받음, 방어적으로 됨, 냉정하게 받아들이는 편, 속으로 삭힘, 바로 개선하려고 함)",
          "gift_giving_style": "how they give gifts in Korean (e.g., 선물 잘 챙기는 편, 깜짝 선물 좋아함, 실용적인 거 사줌, 선물 센스 없음, 선물 주는 거 부담스러움)",
          "gift_receiving_comfort": "how comfortable receiving gifts in Korean (e.g., 선물 받으면 기쁨, 부담스러워함, 미안해함, 자연스럽게 받음, 선물 받는 거 좋아함)",
          "conversation_energy": "social battery size in Korean (e.g., 하루종일 사람 만나도 괜찮음, 2-3시간이 한계, 사람 만나면 피곤함, 혼자 있어야 충전됨, 혼자 있으면 외로움)",
          "small_talk_ability": "chitchat skills in Korean (e.g., 잡담 잘 함, 어색한 침묵 못 참음, 스몰톡 어려움, 깊은 대화 선호, 가벼운 대화 좋아함)",
          "apology_style": "how they apologize in Korean (e.g., 사과 잘 못함, 바로 미안하다고 함, 변명부터 함, 행동으로 보여줌, 사과 안 하는 성격)",
          "superstitions": ["superstition1", "superstition2"],  // Array of 1-3 beliefs or rituals in Korean (e.g., ["숫자 4 싫어함", "시험 날 미역국 안 먹음", "미신 안 믿음", "별자리 챙겨봄"])
          "conflict_history": "past conflicts and how handled in Korean (e.g., 친구랑 크게 싸운 적 없음, 2022년에 절교한 친구 있음, 연인이랑 자주 싸웠음, 가족이랑 갈등 많았음)",
          "support_system": ["support1", "support2"],  // Array of 1-4 support sources in Korean (e.g., ["엄마", "베프", "동아리 친구들", "상담사", "아무도 없음"])
          "background": "detailed personal background in Korean (2-3 sentences)",
          "context": "OBJECTIVE facts about current life situation and circumstances in Korean (2-3 sentences) - NO emotional judgments, only factual information about what is happening in their life, where they are, what they're doing, their schedule, environment, etc.",
          "emotions": ["keyword1", "keyword2", "keyword3"],  // 2-5 emotion keywords (e.g., ["행복", "설렘", "불안"])
          "emotion_description": "current emotional state in Korean (1 sentence) - subjective feelings and mood ONLY",
          "memories": [
            {
              "content": "memory text in Korean",
              "significance": 1.0-10.0,
              "emotional_intensity": 1.0-10.0,
              "tags": ["tag1", "tag2", ...]
            },
            ...
            (8-15 memories total - include a diverse mix of significant life events, relationships, recent experiences, and casual moments to create a realistic human memory profile)
          ]
        }

        MEMORY CREATION GUIDELINES (5W1H Framework):
        Create memories with specificity based on their significance level:

        High Significance (7.0-10.0) - Life-changing events, important people:
        - WHO: Full names and detailed relationship context (예: "고등학교 동창 김민지", "전 남자친구 박준호")
        - WHAT: Specific event details (예: "첫 고백을 받았던 순간", "할머니가 돌아가신 날")
        - WHEN: Specific absolute dates/times (예: "2023년 3월 15일 저녁 7시쯤", "2023년 여름 방학 중", "2021년 겨울")
        - WHERE: Specific locations (예: "학교 뒷산 벤치에서", "강남역 스타벅스 2층", "고향집 거실")
        - WHY: Emotional significance (예: "처음으로 인정받았다고 느꼈던", "내 인생을 바꾼")
        - HOW: Key details of how it happened (예: "갑자기 손을 잡으면서", "편지를 건네주며")

        Medium Significance (4.0-6.9) - Meaningful moments, acquaintances:
        - WHO: Names or general descriptions (예: "동아리 선배", "알바생 친구 수진이")
        - WHAT: General event type (예: "첫 해외여행", "동아리 MT")
        - WHEN: Approximate absolute timeframes (예: "2024년 8월", "2022년 대학교 1학년 때", "2024년 10월")
        - WHERE: General locations (예: "제주도에서", "우리 동네 카페")
        - WHY/HOW: Brief context

        Low Significance (1.0-3.9) - Casual moments, general impressions:
        - Simpler details, can omit specific when/where
        - General descriptions (예: "친구들이랑 놀았던 기억", "맛있는 떡볶이 먹었던 날")

        EMOTIONAL INTENSITY (1.0-10.0):
        Rate the emotional charge of the memory, separate from significance:
        - 9.0-10.0: Intense emotions (첫사랑, 큰 상실, 극심한 기쁨/슬픔)
        - 6.0-8.9: Strong emotions (화남, 실망, 행복했던 순간)
        - 3.0-5.9: Moderate emotions (평범한 긍정/부정 감정)
        - 1.0-2.9: Neutral (담담한 기억, 별 감정 없이)

        TAGS (Associative Retrieval):
        Add 2-5 tags per memory for associative connections:
        - People names (예: "김민지", "엄마", "남친")
        - Places (예: "학교", "강남", "집")
        - Emotions (예: "행복", "슬픔", "분노", "설렘")
        - Themes (예: "우정", "연애", "가족", "학업", "취미")
        - Activities (예: "여행", "공부", "게임", "운동")

        Tags help memories connect - similar tags = related memories that can trigger each other.

        Make it feel like a real person with depth and complexity. Use only Korean for all text fields except 'sex'.
        Rate significance (importance to identity) and emotional_intensity (emotional charge) independently.

        CRITICAL REMINDER: Use REAL, SPECIFIC names throughout - NEVER use placeholders like ○○대학교, ○○회사, ○○구, etc. Examples of real names to use: 서울대학교, 연세대학교, 고려대학교, 성균관대학교, 한양대학교, 이화여대, 카이스트, 포스텍, etc. for universities; 강남구, 마포구, 종로구, 용산구, 신촌, 홍대, 이태원, etc. for locations.

        CRITICAL REMINDER: When referencing time in ANY field (context, background, memories, etc.), always use ABSOLUTE dates/times (e.g., "2025년 11월 3일", "오후 3시", "2023년 여름") instead of relative references (e.g., "오늘", "어제", "며칠 전", "몇 시간 전").

        Respond ONLY with valid JSON, no additional text.
      PROMPT
    end

    def validate_persona_data(data)
      if data.blank?
        Rails.logger.error "Failed to generate persona: empty response from AI"
        raise StandardError, "페르소나 생성 실패: AI 응답이 비어있습니다"
      end

      data = validate_list_fields(data)

      memories_data = data.delete('memories') || []

      first_name = data.delete('first_name')
      last_name = data.delete('last_name')
      status_message = data.delete('status_message')

      data['emotion_timestamp'] = Time.current.to_f

      {
        first_name: first_name,
        last_name: last_name,
        status_message: status_message,
        state_data: data,
        memories: memories_data
      }
    end

    def validate_list_fields(data)
      list_fields = %w[
        personality_traits communication_style interests music_genres values
        speech_patterns social_circle short_term_goals long_term_goals current_worries
        favorite_sounds favorite_scents media_currently_into skills insecurities
        habits nervous_tics pet_peeves language_abilities emotional_triggers
        personal_boundaries allergies_restrictions specific_social_media_platforms
        travel_history significant_achievements regrets secret_desires bucket_list
        role_models phobias_fears comfort_activities current_projects recent_experiences
        superstitions support_system tags
      ]

      list_fields.each do |field|
        next unless data.key?(field) && data[field].present?

        data[field] = [data[field]] if data[field].is_a?(String)
        data[field] = [data[field].to_s] unless data[field].is_a?(Array)
      end

      data
    end
  end
end
