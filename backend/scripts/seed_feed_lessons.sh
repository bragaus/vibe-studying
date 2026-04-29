#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PYTHON_BIN="${BACKEND_DIR}/.venv/bin/python"

if [[ ! -x "${PYTHON_BIN}" ]]; then
  printf 'Python do backend nao encontrado em %s\n' "${PYTHON_BIN}" >&2
  exit 1
fi

export SEED_TEACHER_EMAIL="${SEED_TEACHER_EMAIL:-feed-seeder@example.com}"
export SEED_TEACHER_PASSWORD="${SEED_TEACHER_PASSWORD:-StrongPass123!}"
export SEED_TEACHER_FIRST_NAME="${SEED_TEACHER_FIRST_NAME:-Feed}"
export SEED_TEACHER_LAST_NAME="${SEED_TEACHER_LAST_NAME:-Seeder}"

"${PYTHON_BIN}" "${BACKEND_DIR}/manage.py" shell <<'PY'
import os

from django.utils import timezone

from accounts.models import User
from learning.models import Exercise, ExerciseLine, Lesson


teacher_email = os.environ["SEED_TEACHER_EMAIL"]
teacher_password = os.environ["SEED_TEACHER_PASSWORD"]
teacher_first_name = os.environ["SEED_TEACHER_FIRST_NAME"]
teacher_last_name = os.environ["SEED_TEACHER_LAST_NAME"]


def build_lines(*items):
    return [
        {
            "text_en": text_en,
            "text_pt": text_pt,
            "phonetic_hint": phonetic_hint,
            "reference_start_ms": start_ms,
            "reference_end_ms": end_ms,
        }
        for text_en, text_pt, phonetic_hint, start_ms, end_ms in items
    ]


teacher, created_teacher = User.objects.get_or_create(
    email=teacher_email,
    defaults={
        "first_name": teacher_first_name,
        "last_name": teacher_last_name,
        "role": User.Role.TEACHER,
        "is_active": True,
    },
)

teacher.first_name = teacher_first_name
teacher.last_name = teacher_last_name
teacher.role = User.Role.TEACHER
teacher.is_active = True
teacher.username = teacher.username or teacher_email
teacher.set_password(teacher_password)
teacher.save()


seed_lessons = [
    {
        "title": "Linkin Park - Numb Chorus",
        "description": "Treine um refrao famoso de rock com foco em connected speech.",
        "content_type": Lesson.ContentType.MUSIC,
        "difficulty": Lesson.Difficulty.EASY,
        "tags": ["Linkin Park", "rock", "numb", "chorus"],
        "media_url": "https://www.youtube.com/watch?v=kXYiU_JCYtU",
        "instruction_text": "Cante cada linha no ritmo do refrao.",
        "max_score": 100,
        "lines": build_lines(
            ("I've become so numb.", "Eu fiquei tao anestesiado.", "aiv bikam so nam", 0, 2600),
            ("I can't feel you there.", "Eu nao consigo sentir voce ai.", "ai kent fil iu der", 2600, 5200),
        ),
    },
    {
        "title": "Adele - Hello Opening",
        "description": "Pratique uma entrada melodica com pausas longas e vogais abertas.",
        "content_type": Lesson.ContentType.MUSIC,
        "difficulty": Lesson.Difficulty.MEDIUM,
        "tags": ["Adele", "pop", "hello", "ballad"],
        "media_url": "https://www.youtube.com/watch?v=YQHsXMglC9A",
        "instruction_text": "Repita as linhas com clareza nas vogais.",
        "max_score": 100,
        "lines": build_lines(
            ("Hello, it's me.", "Ola, sou eu.", "rrelou its mi", 0, 2400),
            ("I was wondering if after all these years you'd like to meet.", "Eu queria saber se depois de todos esses anos voce gostaria de se encontrar.", "ai uoz uandarin if after ol diz yirs iud laik tu mit", 2400, 7200),
        ),
    },
    {
        "title": "Queen - We Will Rock You Chant",
        "description": "Treino curto para ritmo, batida e energia de estadio.",
        "content_type": Lesson.ContentType.MUSIC,
        "difficulty": Lesson.Difficulty.EASY,
        "tags": ["Queen", "rock", "anthem", "chant"],
        "media_url": "https://www.youtube.com/watch?v=-tJYN-eG1zk",
        "instruction_text": "Fale as linhas marcando bem o ritmo das pausas.",
        "max_score": 100,
        "lines": build_lines(
            ("Buddy, you're a boy, make a big noise.", "Cara, voce e um garoto, faca barulho.", "badi ior a boi meik a big noiz", 0, 3400),
            ("We will, we will rock you.", "Nos vamos sacudir voce.", "ui uil ui uil rok iu", 3400, 6200),
        ),
    },
    {
        "title": "Naruto - Believe It Scene",
        "description": "Cena curta de anime para treinar enfase e confianca na fala.",
        "content_type": Lesson.ContentType.ANIME_CLIP,
        "difficulty": Lesson.Difficulty.EASY,
        "tags": ["Naruto", "anime", "shonen", "believe it"],
        "media_url": "https://naruto-official.com/en",
        "instruction_text": "Repita com energia, como uma fala de protagonista.",
        "max_score": 100,
        "lines": build_lines(
            ("Believe it!", "Pode acreditar!", "biliv it", 0, 1800),
            ("I'm never giving up.", "Eu nunca vou desistir.", "aim never givind ap", 1800, 4200),
        ),
    },
    {
        "title": "Attack on Titan - Freedom Speech",
        "description": "Trecho intenso para praticar articulacao sob emocao.",
        "content_type": Lesson.ContentType.ANIME_CLIP,
        "difficulty": Lesson.Difficulty.HARD,
        "tags": ["Attack on Titan", "anime", "freedom", "action"],
        "media_url": "https://www.crunchyroll.com/series/GR751KNZY/attack-on-titan",
        "instruction_text": "Repita com projecao e controle de respiracao.",
        "max_score": 100,
        "lines": build_lines(
            ("If we win, we live.", "Se vencermos, nos vivemos.", "if ui uin ui liv", 0, 2200),
            ("If we lose, we die.", "Se perdermos, nos morremos.", "if ui luz ui dai", 2200, 4300),
        ),
    },
    {
        "title": "Spirited Away - Train Scene",
        "description": "Clip contemplativo para treinar fala mais calma e limpa.",
        "content_type": Lesson.ContentType.ANIME_CLIP,
        "difficulty": Lesson.Difficulty.MEDIUM,
        "tags": ["Spirited Away", "Studio Ghibli", "fantasy", "anime"],
        "media_url": "https://www.ghibli.jp/works/chihiro/",
        "instruction_text": "Fale devagar e sustente cada palavra com suavidade.",
        "max_score": 100,
        "lines": build_lines(
            ("Nothing that happens is ever forgotten.", "Nada do que acontece e esquecido.", "nathing dat rapens iz ever forgoten", 0, 3200),
            ("Even if you can't remember it.", "Mesmo se voce nao puder se lembrar disso.", "iven if iu kent rimember it", 3200, 6200),
        ),
    },
    {
        "title": "Interstellar - Docking Scene",
        "description": "Trecho de filme com urgencia, ideal para ouvir e repetir rapido.",
        "content_type": Lesson.ContentType.MOVIE_CLIP,
        "difficulty": Lesson.Difficulty.MEDIUM,
        "tags": ["Interstellar", "movie", "sci-fi", "space"],
        "media_url": "https://www.youtube.com/watch?v=a3lcGnMhvsA",
        "instruction_text": "Repita a fala mantendo o stress nas palavras principais.",
        "max_score": 100,
        "lines": build_lines(
            ("Cooper, this is no time for caution.", "Cooper, esta nao e hora para cautela.", "kuper dis iz nou taim for koxan", 0, 3400),
            ("Analyze the endurance spin.", "Analise o giro da Endurance.", "analai ze endurans spin", 3400, 6200),
        ),
    },
    {
        "title": "Harry Potter - Spell Duel",
        "description": "Cena curta de duelo para praticar comandos curtos e enfaticos.",
        "content_type": Lesson.ContentType.MOVIE_CLIP,
        "difficulty": Lesson.Difficulty.EASY,
        "tags": ["Harry Potter", "movie", "magic", "fantasy"],
        "media_url": "https://www.wizardingworld.com/",
        "instruction_text": "Fale como se estivesse lancando o feitico.",
        "max_score": 100,
        "lines": build_lines(
            ("Expelliarmus!", "Expelliarmus!", "expeliarmas", 0, 1600),
            ("You lose everything.", "Voce perde tudo.", "iu luz evrithing", 1600, 3800),
        ),
    },
    {
        "title": "The Dark Knight - Hero Quote",
        "description": "Treine uma fala iconica com pausas dramaticas.",
        "content_type": Lesson.ContentType.MOVIE_CLIP,
        "difficulty": Lesson.Difficulty.MEDIUM,
        "tags": ["The Dark Knight", "Batman", "movie", "hero"],
        "media_url": "https://www.youtube.com/watch?v=kRZ8-EXlhBo",
        "instruction_text": "Leia pausando nos pontos de impacto da frase.",
        "max_score": 100,
        "lines": build_lines(
            ("You either die a hero.", "Ou voce morre heroi.", "iu aider dai a riro", 0, 2200),
            ("Or you live long enough to see yourself become the villain.", "Ou vive o bastante para se ver virar o vilao.", "or iu liv long inaf tu si iorself bikam de vilan", 2200, 6200),
        ),
    },
    {
        "title": "Friends - We Were on a Break",
        "description": "Cena de sitcom para praticar entonacao de discussao e humor.",
        "content_type": Lesson.ContentType.SERIES_CLIP,
        "difficulty": Lesson.Difficulty.EASY,
        "tags": ["Friends", "series", "comedy", "romance"],
        "media_url": "https://www.youtube.com/watch?v=1nYbP7M7Hf8",
        "instruction_text": "Repita as falas com entonacao de conversa real.",
        "max_score": 100,
        "lines": build_lines(
            ("We were on a break!", "Nos estavamos dando um tempo!", "ui uer on a breik", 0, 2200),
            ("That, for all I knew, could last forever.", "Isso, pelo que eu sabia, podia durar para sempre.", "dat for ol ai niu cud last forevr", 2200, 5600),
        ),
    },
    {
        "title": "The Office - Bears, Beets, Battlestar",
        "description": "Clip curto de comedia para treinar ritmo e listas.",
        "content_type": Lesson.ContentType.SERIES_CLIP,
        "difficulty": Lesson.Difficulty.MEDIUM,
        "tags": ["The Office", "series", "comedy", "workplace"],
        "media_url": "https://www.youtube.com/watch?v=WaaANll8h18",
        "instruction_text": "Repita de forma seca, como um deadpan de sitcom.",
        "max_score": 100,
        "lines": build_lines(
            ("Bears, beets, Battlestar Galactica.", "Ursos, beterrabas, Battlestar Galactica.", "bers bits batlestar galactica", 0, 2600),
            ("Identity theft is not a joke, Jim!", "Roubo de identidade nao e brincadeira, Jim!", "aidentiti theft iz not a djouk djim", 2600, 5600),
        ),
    },
    {
        "title": "Breaking Bad - Yeah Science",
        "description": "Fala curta e marcante para treinar impacto e confianca.",
        "content_type": Lesson.ContentType.SERIES_CLIP,
        "difficulty": Lesson.Difficulty.MEDIUM,
        "tags": ["Breaking Bad", "series", "drama", "science"],
        "media_url": "https://www.youtube.com/watch?v=YRL4uIVzVWI",
        "instruction_text": "Repita com energia e ataque forte nas consoantes.",
        "max_score": 100,
        "lines": build_lines(
            ("Yeah, science!", "Isso, ciencia!", "iea saiens", 0, 1800),
            ("Wire!", "Fio!", "uair", 1800, 2800),
        ),
    },
    {
        "title": "Garfield Charge - Monday Blues",
        "description": "Charge curta para praticar humor seco e vocabulos do dia a dia.",
        "content_type": Lesson.ContentType.CHARGE,
        "difficulty": Lesson.Difficulty.EASY,
        "tags": ["Garfield", "charge", "humor", "monday"],
        "media_url": "https://garfield.com/",
        "instruction_text": "Leia como se fosse uma tira com punchline no fim.",
        "max_score": 100,
        "lines": build_lines(
            ("I hate Mondays.", "Eu odeio segundas-feiras.", "ai reit mandeiz", 0, 1800),
            ("But I love lasagna.", "Mas eu amo lasanha.", "bat ai lav lasanha", 1800, 3600),
        ),
    },
    {
        "title": "Calvin and Hobbes - Homework Joke",
        "description": "Tira para treinar tom ironico e fala infantil espontanea.",
        "content_type": Lesson.ContentType.CHARGE,
        "difficulty": Lesson.Difficulty.EASY,
        "tags": ["Calvin and Hobbes", "charge", "humor", "school"],
        "media_url": "https://www.gocomics.com/calvinandhobbes",
        "instruction_text": "Leia com humor e exagero na ultima linha.",
        "max_score": 100,
        "lines": build_lines(
            ("Homework is bad for my creative growth.", "Licao de casa faz mal para meu crescimento criativo.", "rromuork iz bad for mai criativ grouth", 0, 3200),
            ("I should probably go play outside instead.", "Eu provavelmente deveria ir brincar la fora.", "ai xud probable go plei autsaid insted", 3200, 6200),
        ),
    },
]


created_lessons = 0
updated_lessons = 0

for index, item in enumerate(seed_lessons, start=1):
    lesson, lesson_created = Lesson.objects.update_or_create(
        teacher=teacher,
        title=item["title"],
        defaults={
            "description": item["description"],
            "content_type": item["content_type"],
            "source_type": Lesson.SourceType.EXTERNAL_LINK,
            "difficulty": item["difficulty"],
            "tags": item["tags"],
            "media_url": item["media_url"],
            "status": Lesson.Status.PUBLISHED,
            "published_at": timezone.now(),
        },
    )

    first_line = item["lines"][0]
    exercise, _ = Exercise.objects.update_or_create(
        lesson=lesson,
        defaults={
            "instruction_text": item["instruction_text"],
            "expected_phrase_en": first_line["text_en"],
            "expected_phrase_pt": first_line["text_pt"],
            "max_score": item["max_score"],
        },
    )

    exercise.lines.all().delete()
    ExerciseLine.objects.bulk_create(
        [
            ExerciseLine(
                exercise=exercise,
                order=position,
                text_en=line["text_en"],
                text_pt=line["text_pt"],
                phonetic_hint=line["phonetic_hint"],
                reference_start_ms=line["reference_start_ms"],
                reference_end_ms=line["reference_end_ms"],
            )
            for position, line in enumerate(item["lines"], start=1)
        ]
    )

    if lesson_created:
        created_lessons += 1
        action = "created"
    else:
        updated_lessons += 1
        action = "updated"

    print(f"[{index:02d}] {action}: {lesson.title} ({lesson.content_type}) -> slug={lesson.slug}")


print()
print(f"Teacher {'created' if created_teacher else 'updated'}: {teacher.email}")
print(f"Teacher password reset to: {teacher_password}")
print(f"Lessons created: {created_lessons}")
print(f"Lessons updated: {updated_lessons}")
print(f"Total lessons for this teacher: {Lesson.objects.filter(teacher=teacher).count()}")
print("Use /api/feed or /api/feed/personalized to test the mobile feed.")
PY
