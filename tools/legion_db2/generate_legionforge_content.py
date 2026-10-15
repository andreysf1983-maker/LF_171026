#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LEGIONFORGE 7.3.5 — генератор кастомного контента
=================================================

Скрипт формирует SQL-патчи проекта LEGIONFORGE:

    sql/40_legionforge_items.sql            предметы, валюта, ящики с ресурсами
    sql/41_legionforge_minibosses.sql       100 мировых мини-боссов и их спавны
    sql/42_legionforge_miniboss_loot.sql    уникальный дроп каждого мини-босса
    sql/43_legionforge_upgrade_tokens.sql   токены и вендор улучшений
    sql/44_legionforge_upgrade_limits.sql   пределы улучшения 985 / 1000 / 1200
    sql/45_legionforge_ancient_knowledge.sql свитки «Древнее знание»

Запуск:
    python generate_legionforge_content.py [каталог_проекта]

Все запросы идемпотентны: перед вставкой данные предыдущей установки
удаляются по зарезервированным диапазонам идентификаторов.

Зарезервированные диапазоны LEGIONFORGE
---------------------------------------
  200000-200999   предметы
  210000-219999   эталонные таблицы дропа (reference_loot_template)
  300000-319999   расширенная стоимость (item_extended_cost)
  400000-409999   бонусные списки (item_bonus_list_level_delta)
  900000-900999   неигровые персонажи (creature_template)
  9100000-9100999 спавны (creature.guid)
"""

import io
import os
import sys

# --------------------------------------------------------------------------
# Константы проекта
# --------------------------------------------------------------------------

ESSENCE = 200001          # «Сущность» — валюта LEGIONFORGE
SPHERE = 200300           # «Сфера мастерства» — базовый токен улучшения
VENDOR_BOSS = 900100      # «Хранитель трофеев», Даларан
VENDOR_UPGRADE = 900101   # «Мастер улучшений», Даларан
VENDOR_KNOWLEDGE = 900102 # «Хранитель знаний», Даларан
VENDOR_LEGENDARY = 900103 # «Торговец легендарными предметами», Даларан

ITEM_BASE = 200000        # база диапазона предметов
BOSS_BASE = 900000        # база диапазона мини-боссов
SPAWN_BASE = 9100000      # база диапазона гуидов спавнов
REF_BASE = 210000         # база эталонных таблиц дропа
COST_BASE = 300000        # база расширенной стоимости

VERIFIED = 26124          # билд клиента, для которого предназначен контент

# --------------------------------------------------------------------------
# 1. Ящики с профессионными ресурсами: 1000 единиц одного материала
#    (4 раза по 250 в эталонной таблице — ограничение MaxCount = 255)
# --------------------------------------------------------------------------

CONTAINERS = [
    # (название ящика, id реагента, название реагента)
    ("Ящик с кожей камнедемона",        124113, "Кожа камнедемона"),
    ("Ящик с чешуёй шторма",            124115, "Чешуя шторма"),
    ("Ящик с лейстоуновой рудой",       123918, "Лейстоуновая руда"),
    ("Ящик с фелслейтом",               123919, "Фелслейт"),
    ("Ящик с аетрилом",                 124101, "Аетрил"),
    ("Ящик с грёзником",                124102, "Грёзник"),
    ("Ящик с лисоцветом",               124103, "Лисоцвет"),
    ("Ящик с фьярнскагглом",            124104, "Фьярнскаггл"),
    ("Ящик со звёздной розой",          124105, "Звёздная роза"),
    ("Ящик с фелвортом",                124106, "Фелворт"),
    ("Ящик с шёлком Шаль'дорей",        124437, "Шёлк Шаль'дорей"),
    ("Ящик с арканой",                  124438, "Аркана"),
    ("Ящик с осколками лучезарного света", 124439, "Осколок лучезарного света"),
    ("Ящик с хаотическими кристаллами", 124440, "Хаотический кристалл"),
    ("Ящик с кровью Саргераса",         124124, "Кровь Саргераса"),
    # Гарантированно существующие реагенты классических дополнений
    ("Ящик с льняной тканью",           2589,   "Льняная ткань"),
    ("Ящик с шерстяной тканью",         2592,   "Шерстяная ткань"),
    ("Ящик с шёлковой тканью",          4306,   "Шёлковая ткань"),
    ("Ящик с магической тканью",        4338,   "Магическая ткань"),
    ("Ящик с рунной тканью",            14047,  "Рунная ткань"),
    ("Ящик с толстой кожей",            4234,   "Толстая кожа"),
    ("Ящик с плотной кожей",            4304,   "Плотная кожа"),
    ("Ящик с накладной кожей",          8170,   "Накладная кожа"),
    ("Ящик с железной рудой",           2772,   "Железная руда"),
    ("Ящик с мифриловой рудой",         3858,   "Мифриловая руда"),
    ("Ящик с ториевой рудой",           10620,  "Ториевая руда"),
    ("Ящик с королевской кровью",       3356,   "Королевская кровь"),
    ("Ящик с пурпурным лотосом",        8831,   "Пурпурный лотос"),
    ("Ящик с пылью безумия",            12808,  "Пыль безумия"),
    ("Ящик с субстанцией тьмы",         20520,  "Субстанция Тьмы"),
]

# --------------------------------------------------------------------------
# 2. Редкие предметы, которые невозможно получить игровым путём
# --------------------------------------------------------------------------

RARE_ITEMS = [
    ("Пепельное сердце Бездны",        "Талисман",       4, 1000, "Венчик"),
    ("Клинок Забытого Легиона",        "Одноручный меч", 4, 1000, "Одноручное"),
    ("Плащ Ночной Владычицы",          "Плащ",           4, 1000, "Спина"),
    ("Кольцо Разбитых звёзд",          "Кольцо",         4, 1000, "Палец"),
    ("Посох Хранителя Пламени",        "Двуручный посох",4, 1000, "Двуручное"),
    ("Головной убор Вечного Стража",   "Шлем",           4, 1000, "Голова"),
    ("Наплечники Хранителя Рассвета",  "Наплечники",     4, 1000, "Плечи"),
    ("Перчатки Тихого Убийцы",         "Перчатки",       4, 1000, "Кисти рук"),
    ("Пояс Древних Клятв",             "Пояс",           4, 1000, "Пояс"),
    ("Поножи Сумрачного Странника",    "Поножи",         4, 1000, "Ноги"),
    ("Сапоги Незримого Шага",          "Сапоги",         4, 1000, "Ступни"),
    ("Наручи Каменной Клятвы",         "Наручи",         4, 1000, "Запястья"),
    ("Кулачный щит Непокорных",        "Щит",            4, 1000, "Левая рука"),
    ("Амулет Расколотой Души",         "Амулет",         4, 1000, "Шея"),
    ("Тотем Приливного Пламени",       "Реликвия",       4, 1000, "Реликвия"),
    ("Фолиант Запретных Знаний",       "Фолиант",        4, 1000, "Левая рука"),
    ("Скипетр Грозового Властелина",   "Жезл",           4, 1000, "Одноручное"),
    ("Кинжал Шёпота Бездны",           "Кинжал",         4, 1000, "Одноручное"),
    ("Лук Охотника на Демонов",        "Лук",            4, 1000, "Дальний бой"),
    ("Ружьё Чёрного Пороха",           "Огнестрельное",  4, 1000, "Дальний бой"),
    ("Секира Легиона Пепла",           "Двуручный топор",4, 1000, "Двуручное"),
    ("Молот Судного Часа",             "Двуручный молот",4, 1000, "Двуручное"),
    ("Коса Ночной Погибели",           "Двуручное копьё",4, 1000, "Дуручное"),
    ("Глефа Забвения",                 "Полуторный меч", 4, 1000, "Двуручное"),
    ("Кираса Несокрушимого Стража",    "Кираса",         4, 1000, "Грудь"),
    ("Жилет Тени и Праха",             "Жилет",          4, 1000, "Грудь"),
    ("Одеяние Звёздного Пламени",      "Одеяние",        4, 1000, "Грудь"),
    ("Мантия Круга Тернов",            "Мантия",         4, 1000, "Грудь"),
    ("Знак Отличия Легионфорж",        "Знак отличия",   3, 950,  "Тринкет"),
    ("Кристалл Вечного Мороза",        "Кристалл",       3, 950,  "Тринкет"),
    ("Сердце Горного Великана",        "Сердце",         3, 950,  "Тринкет"),
    ("Око Пустоты",                    "Око",            3, 950,  "Тринкет"),
    ("Печать Древних Королей",         "Печать",         3, 950,  "Тринкет"),
    ("Прах Сожжённой Короны",          "Прах",           3, 950,  "Тринкет"),
    ("Слеза Лунной Богини",            "Слеза",          3, 950,  "Тринкет"),
    ("Руна Безмолвного Стража",        "Руна",           3, 950,  "Тринкет"),
    ("Эмблема Пробуждённых",           "Эмблема",        3, 950,  "Тринкет"),
    ("Наследие Алого Рассвета",        "Наследие",       3, 950,  "Тринкет"),
    ("Свиток Неизречённого Знания",    "Свиток",         3, 950,  "Реликвия"),
    ("Пламя Негасимого Костра",        "Пламя",          3, 950,  "Реликвия"),
]

# --------------------------------------------------------------------------
# 3. Сотня мировых мини-боссов
#    (имя, прозвище, множитель здоровья, множитель урона, ранг)
# --------------------------------------------------------------------------

BOSS_NAMES = [
    "Пепельный Пожиратель", "Хранитель Гнилой Короны", "Матерь Паучьей Тьмы",
    "Глашатай Бездны", "Костяной Жнец", "Владыка Пылающих Углей",
    "Страж Забытых Врат", "Колдун Багрового Тумана", "Пожиратель Душ",
    "Надзиратель Пепла", "Осквернённый Друид", "Хозяин Болотного Тумана",
    "Шепчущий Ужас", "Мясник Тёмного Обелиска", "Повелитель Костяных Волн",
    "Чумной Кузнец", "Тень Ночной Владычицы", "Разрушитель Рассвета",
    "Владыка Ледяных Пустошей", "Смотритель Пламени", "Жрец Безмолвия",
    "Ворон Пепельного Неба", "Громовержец Скал", "Мастер Забытого Ремесла",
    "Сектант Алого Рассвета", "Кровавый Страж", "Гниющий Полководец",
    "Древень Чёрного Корня", "Призрак Утраченной Клятвы", "Ловчий Бездны",
    "Хозяин Стального Капкана", "Певчий Тёмной Зари", "Сторож Глубин",
    "Палач Пепельного Легиона", "Хранительница Лунного Колодца", "Разоритель Надежды",
    "Тотемист Пепла", "Некромант Чёрного Холма", "Страж Тихого Пролива",
    "Властелин Бурь", "Искатель Забытых Истин", "Гвардеец Тёмного Владыки",
    "Плакальщица Ночи", "Клинок Рассвета", "Мастер Ядовитых Клинков",
    "Носитель Проклятия", "Огненный Левиафан", "Ледяной Крушитель",
    "Повелитель Болотной Топи", "Ткач Теней", "Служитель Пепла",
    "Костолом Северных Башен", "Владыка Грозовой Гряды", "Жнец Тёмного Железа",
    "Хозяин Скалистого Пика", "Хранитель Забытого Света", "Мститель Глубин",
    "Повелитель Пылающих Песков", "Тень Над Пустошью", "Паладин Забытого Света",
    "Госпожа Чёрного Шёлка", "Тихий Убийца", "Разрушитель Каменных Врат",
    "Страж Утраченного Храма", "Мастер Стального Круга", "Пожиратель Пламени",
    "Костяной Жрец", "Глашатай Тёмного Легиона", "Владыка Лунного Клинка",
    "Тотемный Страж", "Хозяин Чёрного Котла", "Смотритель Тёмных Залов",
    "Разоритель Древних Стен", "Чумной Владыка", "Повелитель Каменных Духов",
    "Тень Над Башней", "Хранитель Кристальных Скал", "Певец Тёмных Глубин",
    "Грозовой Жрец", "Пепельный Жнец", "Мясник Тёмного Оброка",
    "Владыка Огненного Круга", "Хозяин Ледяной Цитадели", "Колдун Чёрного Пламени",
    "Страж Ночных Пустошей", "Ткач Пепельной Судьбы", "Повелитель Костяного Трона",
    "Разрушитель Звёздного Печатя", "Хранитель Грёзного Ключа", "Тень Забытого Владыки",
    "Мастер Проклятых Клинков", "Глашатай Багрового Рассвета", "Владыка Тихого Холма",
    "Костяной Страж", "Хозяин Багрового Знамени", "Смотритель Тёмного Пламени",
    "Последний Страж Легиона", "Вечный Пепельный Хранитель", "Повелитель Забытой Бездны",
    "Матерь Тёмного Гнезда", "Владыка Негасимого Костра",
]

# --------------------------------------------------------------------------
# 4. Свитки «Древнее знание» — восстановленные способности классов
#    (название умения, id заклинания, id класса или 0, описание)
# --------------------------------------------------------------------------

ANCIENT_KNOWLEDGE = [
    ("Метаморфоза",              47241,   9,  "Облик демона для чернокнижника-демонолога"),
    ("Демонический облик",       114168,  9,  "Классическая форма демона со своими заклинаниями"),
    ("Демонический круг",        48018,   9,  "Ритуальный круг для мгновенного перемещения"),
    ("Жертвенность",             7812,    9,  "Поглощение урона питомцем вместо хозяина"),
    ("Проклятье изнеможения",    18223,   9,  "Замедление цели"),
    ("Проклятье касания",        1714,    9,  "Снижение скорости заклинаний цели"),
    ("Облик лютого волка",       768,     11, "Древний облик друида, утраченный в прежних версиях"),
    ("Форма кошки",              768,     11, "Боевой облик друида"),
    ("Симбиоз",                  110309,  11, "Обмен способностями с союзником"),
    ("Лапка",                    1079,    11, "Древнее умение друида-ферала"),
    ("Облик медведя",            5487,    11, "Защитный облик друида"),
    ("Облик оленя",              21005,   11, "Форма передвижения друида"),
    ("Знак дикой природы",       1126,    11, "Усиление характеристик группы"),
    ("Водный облик",             1066,    11, "Плавание друида"),
    ("Благословение могущества", 19740,   2,  "Аура силы атаки для группы"),
    ("Благословение королей",    20217,   2,  "Аура характеристик для группы"),
    ("Великое благословение могущества", 25782, 2, "Групповое благословение могущества"),
    ("Великое благословение королей", 25898, 2,  "Групповое благословение королей"),
    ("Божественный щит",         642,     2,  "Полная неуязвимость на короткое время"),
    ("Гнев карателя",            20066,   2,  "Сокрушение нечестивых"),
    ("Ледяная броня",            7302,    8,  "Классическая защитная аура мага"),
    ("Доспехи мага",             6117,    8,  "Регенерация маны в бою"),
    ("Щит маны",                 1463,    8,  "Поглощение урона маной"),
    ("Взрыв разума",             8092,    5,  "Атакующее заклинание теней"),
    ("Молитва духа",             27681,   5,  "Групповой бафф духа"),
    ("Божественный дух",         14752,   5,  "Классический бафф духа"),
    ("Внутренний огонь",         588,     5,  "Увеличение силы заклинаний"),
    ("Царство теней",            15473,   5,  "Облик тени жреца"),
    ("Боевой крик",              6673,    1,  "Аура силы атаки воина"),
    ("Командирский крик",        469,     1,  "Увеличение запаса здоровья"),
    ("Кровавая ярость",          2687,    1,  "Мгновенное восстановление ярости"),
    ("Безрассудная атака",       1719,    1,  "Классический рывок воина"),
    ("Жажда крови",              2825,    7,  "Групповое ускорение атаки"),
    ("Героизм",                  32182,   7,  "Групповое ускорение атаки"),
    ("Тотем неистовства ветра",  8512,    7,  "Тотем скорости атаки"),
    ("Исцеление предков",        16190,   7,  "Мощное восстановление группы"),
    ("Смертельный удар",         5308,    4,  "Классическая способность разбойника"),
    ("Внезапный удар",           1752,    4,  "Классический удар разбойника"),
    ("Калечащий яд",             3409,    4,  "Замедляющий яд"),
    ("Призыв коня Скверны",      5784,    9,  "Классический транспорт чернокнижника"),
    ("Ужасный конь",             23161,   9,  "Древний конь чернокнижника"),
    ("Звериный гнев",            19574,   3,  "Ярость охотника и его питомца"),
    ("Знание троп",              1002,    3,  "Классическая способность охотника"),
    ("Глаз зверя",               6197,    3,  "Разведка через питомца"),
    ("Призыв призрачного волка", 51533,   7,  "Духовный союзник шамана"),
    ("Каменная форма",           20594,   0,  "Расовая способность дворфа"),
    ("Теневой облик",            20580,   0,  "Расовая способность ночной эльфийки"),
    ("Дар наару",                28880,   0,  "Расовая способность дренея"),
    ("Кровавая ярость орка",     20572,   0,  "Расовая способность орка"),
    ("Воля Отрекшихся",          7744,    0,  "Расовая способность Отрекшихся"),
]

# --------------------------------------------------------------------------
# 5. Легендарные предметы и их улучшения 1000 -> 1200 шагом +5
# --------------------------------------------------------------------------

LEGENDARY_BASES = [
    ("Клинок Пепельного Пламени",     1000, "Одноручное",  2, 13, "Меч"),
    ("Скипетр Забытого Владыки",     1000, "Одноручное",  2, 10, "Жезл"),
    ("Глефа Вечного Стража",         1000, "Двуручное",   2,  6, "Глефа"),
    ("Кольцо Разбитых звёзд",        1000, "Палец",       4, -1, "Кольцо"),
    ("Плащ Ночной Владычицы",        1000, "Спина",       4, -1, "Плащ"),
    ("Талисман Пепельного Сердца",   1000, "Тринкет",     4, -1, "Тринкет"),
    ("Кираса Несокрушимого Стража",  1000, "Грудь",       4,  4, "Кираса"),
    ("Посох Хранителя Пламени",      1000, "Двуручное",   2, 10, "Посох"),
]

LEGENDARY_MIN = 1000
LEGENDARY_MAX = 1200
LEGENDARY_STEP = 5

# --------------------------------------------------------------------------
# 6. Экипировка профессий: 985 -> 1000 ilvl
# --------------------------------------------------------------------------

CRAFTED_BASES = [
    ("Жилет Тени и Праха",        950, "Грудь",    4,  2, 165, "Кожевничество"),
    ("Шлем Закалённого Латника",  950, "Голова",   4,  4, 164, "Кузнечное дело"),
    ("Одеяние Звёздного Пламени", 950, "Грудь",    4,  1, 197, "Портняжное дело"),
    ("Наплечники Стального Круга",950, "Плечи",    4,  3, 164, "Кузнечное дело"),
    ("Перчатки Тихого Убийцы",    950, "Кисти рук",4,  2, 165, "Кожевничество"),
    ("Пояс Древних Клятв",        950, "Пояс",     4,  1, 197, "Портняжное дело"),
]

CRAFTED_MAX = 1000
CRAFTED_STEP = 5

# Профессии и токены улучшений
PROFESSIONS = [
    # (id навыка, название профессии, id токена, название токена, реагенты)
    (165, "Кожевничество",     200301, "Окаменевшая чешуя",
     [(124113, 250, "Кожа камнедемона"), (124115, 250, "Чешуя шторма"),
      (8170, 250, "Накладная кожа"), (4304, 250, "Плотная кожа"), (124124, 20, "Кровь Саргераса")]),
    (164, "Кузнечное дело",    200302, "Закалённый слиток",
     [(123918, 250, "Лейстоуновая руда"), (123919, 250, "Фелслейт"),
      (3858, 250, "Мифриловая руда"), (10620, 250, "Ториевая руда"), (124124, 20, "Кровь Саргераса")]),
    (197, "Портняжное дело",   200303, "Нить сотканной ткани",
     [(124437, 250, "Шёлк Шаль'дорей"), (14047, 250, "Рунная ткань"),
      (4338, 250, "Магическая ткань"), (4306, 250, "Шёлковая ткань"), (124124, 20, "Кровь Саргераса")]),
    (202, "Инженерное дело",   200304, "Хитросплетённый механизм",
     [(123918, 250, "Лейстоуновая руда"), (123919, 250, "Фелслейт"),
      (2772, 250, "Железная руда"), (3858, 250, "Мифриловая руда"), (124124, 20, "Кровь Саргераса")]),
    (755, "Ювелирное дело",    200305, "Гранёный кристалл",
     [(124440, 100, "Хаотический кристалл"), (124439, 100, "Осколок лучезарного света"),
      (124438, 250, "Аркана"), (12808, 250, "Пыль безумия"), (124124, 20, "Кровь Саргераса")]),
    (333, "Наложение чар",     200306, "Руническая пыль",
     [(124438, 250, "Аркана"), (124439, 100, "Осколок лучезарного света"),
      (20520, 250, "Субстанция Тьмы"), (12808, 250, "Пыль безумия"), (124124, 20, "Кровь Саргераса")]),
]

# Навыки ремесла, необходимые для покупки токена
PROFESSION_SKILL_MIN = 800


# --------------------------------------------------------------------------
# Вспомогательные функции
# --------------------------------------------------------------------------

def sql_str(value):
    """Экранирование строковой константы для MySQL."""
    return "'" + str(value).replace("\\", "\\\\").replace("'", "\\'") + "'"


def ext_cost_row(cost_id, item1, item2, item3, count1, count2, count3):
    """Строка item_extended_cost (28 колонок).

    item1/item2/item3 - идентификаторы требуемых предметов,
    count1/count2/count3 - их количество.
    """
    vals = [cost_id, item1, item2, item3, 0, 0,
            0, 0, 0, 0, 0,
            count1, count2, count3, 0, 0,
            0,
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0,
            VERIFIED]
    assert len(vals) == 28, len(vals)
    return "(" + ",".join(str(v) for v in vals) + ")"


class Writer:
    def __init__(self, title):
        self.buf = io.StringIO()
        self.buf.write("-- " + "=" * 74 + "\n")
        for line in title.split("\n"):
            self.buf.write("--   " + line + "\n")
        self.buf.write("-- " + "=" * 74 + "\n")
        self.buf.write("-- Файл сгенерирован автоматически: tools/legion_db2/"
                       "generate_legionforge_content.py\n")
        self.buf.write("-- Билд клиента: %d. Изменяйте данные в генераторе, "
                       "а не в этом файле.\n" % VERIFIED)
        self.buf.write("-- Запросы идемпотентны, повторное применение безопасно.\n")
        self.buf.write("-- " + "=" * 74 + "\n\n")
        self.buf.write("SET NAMES utf8mb4;\nSET FOREIGN_KEY_CHECKS = 0;\n\n")

    def add(self, text):
        self.buf.write(text)
        if not text.endswith("\n"):
            self.buf.write("\n")

    def section(self, name):
        self.buf.write("\n-- " + "-" * 74 + "\n-- " + name + "\n-- " + "-" * 74 + "\n\n")

    def save(self, path):
        self.buf.write("\nSET FOREIGN_KEY_CHECKS = 1;\n")
        with io.open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(self.buf.getvalue())


def item_rows(items):
    """Формирует INSERT в item и item_sparse.

    items: список кортежей
      (id, имя, класс, подкласс, тип инвентаря, качество, уровень предмета,
       описание)
    """
    out = io.StringIO()
    out.write("USE `hotfixes`;\n\n")
    out.write("DELETE FROM `item` WHERE `ID` BETWEEN 200000 AND 209999;\n")
    out.write("DELETE FROM `item_sparse` WHERE `ID` BETWEEN 200000 AND 209999;\n")
    out.write("DELETE FROM `item_effect` WHERE `ItemID` BETWEEN 200000 AND 209999;\n\n")

    out.write("INSERT INTO `item` (`ID`,`FileDataID`,`Class`,`SubClass`,"
              "`SoundOverrideSubclass`,`Material`,`InventoryType`,`Sheath`,"
              "`GroupSoundsID`,`VerifiedBuild`) VALUES\n")
    lines = []
    for (iid, name, cls, sub, inv, quality, ilvl, desc) in items:
        lines.append("(%d,%d,%d,%d,0,-1,%d,0,0,%d)" % (iid, iid, cls, sub, inv, VERIFIED))
    out.write(",\n".join(lines) + ";\n\n")

    out.write("INSERT INTO `item_sparse` (`ID`,`Name`,`Name2`,`Name3`,`Name4`,"
              "`Description`,`Flags1`,`Flags2`,`Flags3`,`Flags4`,`BuyCount`,"
              "`BuyPrice`,`SellPrice`,`MaxCount`,`Stackable`,`AllowableClass`,"
              "`AllowableRace`,`ItemLevel`,`Quality`,`InventoryType`,"
              "`ContainerSlots`,`Bonding`,`RequiredLevel`,`Material`,`Sheath`,"
              "`RequiredExpansion`,`VerifiedBuild`) VALUES\n")
    lines = []
    for (iid, name, cls, sub, inv, quality, ilvl, desc) in items:
        lines.append("(%d,%s,'','','',%s,0,0,0,0,1,%d,%d,0,200,-1,-1,%d,%d,%d,0,1,100,-1,0,6,%d)"
                     % (iid, sql_str(name), sql_str(desc), max(1000, ilvl * 2),
                        max(500, ilvl), ilvl, quality, inv, VERIFIED))
    out.write(",\n".join(lines) + ";\n")
    return out.getvalue()


# --------------------------------------------------------------------------
# Генерация sql/40_legionforge_items.sql
# --------------------------------------------------------------------------

def build_items(path):
    w = Writer("LEGIONFORGE 7.3.5 - предметы, валюта и ящики с ресурсами\n"
               "Файл: sql/40_legionforge_items.sql")
    w.section("1. Базовые предметы LEGIONFORGE")

    items = []
    items.append((ESSENCE, "Сущность", 15, 0, 0, 4, 1,
                  "Валюта LEGIONFORGE. Падает с мировых мини-боссов и тратится "
                  "у вендора легендарных предметов в Даларане."))
    items.append((SPHERE, "Сфера мастерства", 7, 2, 0, 4, 1,
                  "Базовый токен улучшения экипировки. Изготавливается "
                  "мастерами профессий LEGIONFORGE."))

    w.section("2. Ящики с профессионными ресурсами (по 1000 единиц)")
    container_ids = []
    for index, (box_name, reagent_id, reagent_name) in enumerate(CONTAINERS):
        cid = 200100 + index
        container_ids.append((cid, reagent_id))
        items.append((cid, box_name, 15, 0, 0, 3, 1,
                      "Содержит 1000 единиц: %s." % reagent_name))

    w.section("3. Редкие предметы, недостижимые обычным игровым путём")
    rare_ids = []
    for index, (name, kind, quality, ilvl, slot) in enumerate(RARE_ITEMS):
        rid = 200400 + index
        rare_ids.append(rid)
        items.append((rid, name, 4, 0, 0, quality, ilvl,
                      "%s. Редчайшая добыча мировых мини-боссов LEGIONFORGE." % kind))

    w.section("4. Свитки «Древнее знание»")
    scroll_ids = []
    for index, (ability, spell_id, class_id, desc) in enumerate(ANCIENT_KNOWLEDGE):
        sid = 200200 + index
        scroll_ids.append((sid, spell_id, class_id))
        items.append((sid, "Древнее знание: %s" % ability, 15, 0, 0, 4, 1,
                      "Свиток «Древнее знание». При использовании изучает "
                      "способность «%s». %s." % (ability, desc)))

    w.section("5. Токены улучшений профессий")
    for skill_id, prof_name, token_id, token_name, reagents in PROFESSIONS:
        items.append((token_id, token_name, 7, 2, 0, 4, 1,
                      "Токен улучшения. Изготавливается только мастером "
                      "профессии «%s»." % prof_name))

    w.section("6. Легендарные предметы и их улучшения 1000 -> 1200")
    legendary_rows = []   # (item_id, ilvl, base_index, tier, name)
    for base_index, (base_name, base_ilvl, inv_slot, quality, sub, kind) in enumerate(LEGENDARY_BASES):
        base_id = 200500 + base_index
        items.append((base_id, base_name, 4, sub, 0, quality, base_ilvl,
                      "Легендарный предмет LEGIONFORGE. Улучшается у Мастера "
                      "улучшений в Даларане до %d ilvl." % LEGENDARY_MAX))
        legendary_rows.append((base_id, base_ilvl, base_index, 0, base_name))
        tier = 0
        ilvl = base_ilvl + LEGENDARY_STEP
        while ilvl <= LEGENDARY_MAX:
            tier += 1
            item_id = 200510 + base_index * 100 + tier
            items.append((item_id, "%s [%d]" % (base_name, ilvl), 4, sub, 0,
                          quality, ilvl,
                          "Легендарный предмет LEGIONFORGE, улучшение %d из %d."
                          % (tier, (LEGENDARY_MAX - base_ilvl) // LEGENDARY_STEP)))
            legendary_rows.append((item_id, ilvl, base_index, tier, base_name))
            ilvl += LEGENDARY_STEP

    w.section("7. Экипировка профессий и её улучшение до 1000 ilvl")
    crafted_rows = []
    for base_index, (base_name, base_ilvl, inv_slot, quality, sub, skill_id, prof_name) in enumerate(CRAFTED_BASES):
        base_id = 200700 + base_index
        items.append((base_id, base_name, 4, sub, 0, quality, base_ilvl,
                      "Экипировка, созданная профессией «%s». Улучшается до "
                      "%d ilvl." % (prof_name, CRAFTED_MAX)))
        crafted_rows.append((base_id, base_ilvl, base_index, 0, base_name, skill_id, prof_name))
        tier = 0
        ilvl = base_ilvl + CRAFTED_STEP
        while ilvl <= CRAFTED_MAX:
            tier += 1
            item_id = 200710 + base_index * 100 + tier
            items.append((item_id, "%s [%d]" % (base_name, ilvl), 4, sub, 0,
                          quality, ilvl,
                          "Экипировка профессии «%s», улучшение %d."
                          % (prof_name, tier)))
            crafted_rows.append((item_id, ilvl, base_index, tier, base_name, skill_id, prof_name))
            ilvl += CRAFTED_STEP

    w.add(item_rows(items))

    w.section("8. Использование свитков «Древнее знание»")
    w.add("DELETE FROM `item_effect` WHERE `ItemID` BETWEEN 200200 AND 200249;")
    w.add("DELETE FROM `spell_effect` WHERE `SpellID` BETWEEN 200200 AND 200249;")
    w.add("DELETE FROM `spell` WHERE `ID` BETWEEN 200200 AND 200249;")
    w.add("")
    w.add("-- Заклинание-обучение: эффект 33 (SPELL_EFFECT_LEARN_SPELL).")
    w.add("-- Если в вашей сборке SpellEffects.db2 использует другой номер, "
          "исправьте значение Effect ниже.")
    rows = []
    for index, (ability, spell_id, class_id, desc) in enumerate(ANCIENT_KNOWLEDGE):
        teach = 200200 + index
        rows.append("(%d,'Древнее знание: %s','','%s','',%d)" % (
            teach, ability, desc, VERIFIED))
    w.add("INSERT INTO `spell` (`ID`,`Name`,`NameSubtext`,`Description`,"
          "`AuraDescription`,`VerifiedBuild`) VALUES")
    w.add(",\n".join(rows) + ";")
    w.add("")
    rows = []
    for index, (ability, spell_id, class_id, desc) in enumerate(ANCIENT_KNOWLEDGE):
        teach = 200200 + index
        vals = [teach, 33, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, spell_id,
                0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, teach, VERIFIED]
        assert len(vals) == 37, len(vals)
        rows.append("(" + ",".join(str(v) for v in vals) + ")")
    w.add("INSERT INTO `spell_effect` (`ID`,`Effect`,`EffectBasePoints`,"
          "`EffectIndex`,`EffectAura`,`DifficultyID`,`EffectAmplitude`,"
          "`EffectAuraPeriod`,`EffectBonusCoefficient`,`EffectChainAmplitude`,"
          "`EffectChainTargets`,`EffectDieSides`,`EffectItemType`,"
          "`EffectMechanic`,`EffectPointsPerResource`,`EffectRealPointsPerLevel`,"
          "`EffectTriggerSpell`,`EffectPosFacing`,`EffectAttributes`,"
          "`BonusCoefficientFromAP`,`PvPMultiplier`,`Coefficient`,`Variance`,"
          "`ResourceCoefficient`,`GroupSizeCoefficient`,"
          "`EffectSpellClassMask1`,`EffectSpellClassMask2`,"
          "`EffectSpellClassMask3`,`EffectSpellClassMask4`,`EffectMiscValue`,"
          "`EffectMiscValueB`,`EffectRadiusIndex`,`EffectRadiusMaxIndex`,"
          "`ImplicitTarget1`,`ImplicitTarget2`,`SpellID`,`VerifiedBuild`) VALUES")
    w.add(",\n".join(rows) + ";")
    w.add("")
    w.add("INSERT INTO `item_effect` (`ID`,`SpellID`,`Cooldown`,"
          "`CategoryCooldown`,`Charges`,`Category`,`ChrSpecializationID`,"
          "`OrderIndex`,`Trigger`,`ItemID`,`VerifiedBuild`) VALUES")
    rows = []
    for index, (ability, spell_id, class_id, desc) in enumerate(ANCIENT_KNOWLEDGE):
        teach = 200200 + index
        rows.append("(%d,%d,0,0,1,0,0,0,0,%d,%d)" % (teach, teach, teach, VERIFIED))
    w.add(",\n".join(rows) + ";")

    w.section("9. Ящики с ресурсами: содержимое")
    w.add("USE `world`;\n")
    w.add("DELETE FROM `item_loot_template` WHERE `Entry` BETWEEN 200100 AND 200129;")
    w.add("DELETE FROM `reference_loot_template` WHERE `Entry` BETWEEN %d AND %d;"
          % (REF_BASE, REF_BASE + 299))
    w.add("")
    w.add("-- Ограничение движка: MaxCount не превышает 255, поэтому 1000 "
          "единиц собираются из четырёх бросков по 250.")
    ref_rows = []
    loot_rows = []
    for index, (box_name, reagent_id, reagent_name) in enumerate(CONTAINERS):
        cid = 200100 + index
        ref = REF_BASE + index
        ref_rows.append("(%d,%d,0,100,0,1,0,250,250,%s)" % (
            ref, reagent_id, sql_str("Ящик LEGIONFORGE: %s" % reagent_name)))
        for part in range(1, 5):
            loot_rows.append("(%d,%d,%d,100,0,1,0,1,1,%s)" % (
                cid, part, ref, sql_str("Часть %d из 4" % part)))
    w.add("INSERT INTO `reference_loot_template` (`Entry`,`Item`,`Reference`,"
          "`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,"
          "`MaxCount`,`Comment`) VALUES")
    w.add(",\n".join(ref_rows) + ";")
    w.add("")
    w.add("INSERT INTO `item_loot_template` (`Entry`,`Item`,`Reference`,"
          "`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,"
          "`MaxCount`,`Comment`) VALUES")
    w.add(",\n".join(loot_rows) + ";")
    w.save(path)


# --------------------------------------------------------------------------
# Генерация sql/41_legionforge_minibosses.sql
# --------------------------------------------------------------------------

def build_bosses(path):
    w = Writer("LEGIONFORGE 7.3.5 - 100 мировых мини-боссов\n"
               "Файл: sql/41_legionforge_minibosses.sql\n"
               "Идентификаторы: creature_template 900000-900099, "
               "creature.guid 9100000-9100099")
    w.section("1. Очистка зарезервированного диапазона")
    w.add("USE `world`;\n")
    w.add("DELETE FROM `creature` WHERE `guid` BETWEEN %d AND %d;"
          % (SPAWN_BASE, SPAWN_BASE + 99))
    w.add("DELETE FROM `creature_template_addon` WHERE `entry` BETWEEN %d AND %d;"
          % (BOSS_BASE, BOSS_BASE + 99))
    w.add("DELETE FROM `creature_loot_template` WHERE `Entry` BETWEEN %d AND %d;"
          % (BOSS_BASE, BOSS_BASE + 99))
    w.add("DELETE FROM `creature_template` WHERE `entry` BETWEEN %d AND %d;"
          % (BOSS_BASE, BOSS_BASE + 99))

    w.section("2. Описание мини-боссов")
    w.add("DROP TEMPORARY TABLE IF EXISTS `tmp_legionforge_bosses`;")
    w.add("CREATE TEMPORARY TABLE `tmp_legionforge_bosses` (")
    w.add("  `rn` INT NOT NULL,")
    w.add("  `name` VARCHAR(200) NOT NULL,")
    w.add("  `subname` VARCHAR(200) NOT NULL,")
    w.add("  `rank` TINYINT NOT NULL,")
    w.add("  `hp` FLOAT NOT NULL,")
    w.add("  `dmg` FLOAT NOT NULL,")
    w.add("  `gold` INT NOT NULL,")
    w.add("  PRIMARY KEY (`rn`)")
    w.add(") ENGINE=Memory DEFAULT CHARSET=utf8mb4;")
    w.add("")
    rows = []
    total = len(BOSS_NAMES)
    for index in range(100):
        name = BOSS_NAMES[index % total]
        rank = 2 if index % 5 else 3          # редкий элитный / мировой босс
        hp = 35.0 + (index % 12) * 4.5
        dmg = 2.5 + (index % 8) * 0.45
        gold = 2500 + (index % 20) * 350
        rows.append("(%d,%s,'Мини-босс LEGIONFORGE',%d,%.1f,%.2f,%d)" % (
            index + 1, sql_str(name), rank, hp, dmg, gold))
    w.add("INSERT INTO `tmp_legionforge_bosses`"
          " (`rn`,`name`,`subname`,`rank`,`hp`,`dmg`,`gold`) VALUES")
    w.add(",\n".join(rows) + ";")

    w.section("3. Шаблоны существ")
    w.add("-- Модели берутся из существующих записей базы данных, поэтому "
          "гарантированно корректны для билда %d." % VERIFIED)
    w.add("INSERT INTO `creature_template` (`entry`,`name`,`femaleName`,"
          "`subname`,`minlevel`,`maxlevel`,`HealthScalingExpansion`,"
          "`RequiredExpansion`,`faction`,`npcflag`,`speed_walk`,`speed_run`,"
          "`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,"
          "`BaseVariance`,`RangeVariance`,`unit_class`,`type`,`lootid`,"
          "`mingold`,`maxgold`,`AIName`,`MovementType`,`HealthModifier`,"
          "`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,"
          "`RegenHealth`,`mechanic_immune_mask`,`flags_extra`,`ScriptName`,"
          "`VerifiedBuild`)")
    w.add("SELECT %d + `rn` - 1, `name`, '', `subname`, 110, 110, 6, 6, 14, 0,"
          % BOSS_BASE)
    w.add("       1, 1.14286, 1.35, `rank`, 0, 2000, 2000, 1, 1, 1, 7,"
          " %d + `rn` - 1, `gold`, `gold` * 2, '', 1," % BOSS_BASE)
    w.add("       `hp`, 1, 1, `dmg`, 1, 1, 0, 0, '', %d" % VERIFIED)
    w.add("FROM `tmp_legionforge_bosses`;")
    w.add("")
    w.add("-- Подстановка моделей и визуальных параметров существующих существ.")
    w.add("UPDATE `creature_template` ct")
    w.add("JOIN (")
    w.add("  SELECT ROW_NUMBER() OVER (ORDER BY `entry`) AS `rn`, `modelid1`,"
          " `modelid2`, `modelid3`, `modelid4`, `family`, `type_flags`")
    w.add("  FROM `creature_template`")
    w.add("  WHERE `entry` < %d AND `modelid1` > 0" % BOSS_BASE)
    w.add(") src ON src.`rn` = ct.`entry` - %d" % (BOSS_BASE - 1))
    w.add("SET ct.`modelid1` = src.`modelid1`, ct.`modelid2` = src.`modelid2`,"
          " ct.`modelid3` = src.`modelid3`, ct.`modelid4` = src.`modelid4`,")
    w.add("    ct.`family` = src.`family`, ct.`type_flags` = src.`type_flags`")
    w.add("WHERE ct.`entry` BETWEEN %d AND %d;" % (BOSS_BASE, BOSS_BASE + 99))

    w.section("4. Дополнения шаблонов")
    w.add("INSERT INTO `creature_template_addon` (`entry`,`path_id`,`mount`,"
          "`bytes1`,`bytes2`,`emote`,`aiAnimKit`,`movementAnimKit`,"
          "`meleeAnimKit`,`auras`)")
    w.add("SELECT `entry`, 0, 0, 0, 1, 0, 0, 0, 0, ''")
    w.add("FROM `creature_template` WHERE `entry` BETWEEN %d AND %d;"
          % (BOSS_BASE, BOSS_BASE + 99))

    w.section("5. Расстановка по миру")
    w.add("-- Координаты берутся из таблицы game_tele: это проверенные точки "
          "с корректной высотой Z.")
    w.add("INSERT INTO `creature` (`guid`,`id`,`map`,`zoneId`,`areaId`,"
          "`spawnMask`,`PhaseId`,`PhaseGroup`,`modelid`,`equipment_id`,"
          "`position_x`,`position_y`,`position_z`,`orientation`,"
          "`spawntimesecs`,`spawndist`,`currentwaypoint`,`curhealth`,"
          "`curmana`,`MovementType`,`ScriptName`,`VerifiedBuild`)")
    w.add("SELECT %d + `rn` - 1, %d + `rn` - 1, `map`, 0, 0, 1, 0, 0, 0, 0,"
          % (SPAWN_BASE, BOSS_BASE))
    w.add("       `position_x`, `position_y`, `position_z`, `orientation`,"
          " 7200, 20, 0, 1, 0, 1, '', %d" % VERIFIED)
    w.add("FROM (")
    w.add("  SELECT ROW_NUMBER() OVER (ORDER BY `id`) AS `rn`, `map`,"
          " `position_x`, `position_y`, `position_z`, `orientation`")
    w.add("  FROM `game_tele`")
    w.add("  WHERE `map` IN (0, 1, 530, 571, 870, 1220)")
    w.add("    AND `name` NOT LIKE '%City%'")
    w.add("    AND `name` NOT LIKE '%Stormwind%'")
    w.add("    AND `name` NOT LIKE '%Orgrimmar%'")
    w.add(") tele")
    w.add("WHERE `rn` <= 100;")
    w.add("")
    w.add("DROP TEMPORARY TABLE IF EXISTS `tmp_legionforge_bosses`;")
    w.save(path)


# --------------------------------------------------------------------------
# Генерация sql/42_legionforge_miniboss_loot.sql
# --------------------------------------------------------------------------

def build_loot(path):
    w = Writer("LEGIONFORGE 7.3.5 - уникальный дроп мини-боссов\n"
               "Файл: sql/42_legionforge_miniboss_loot.sql")
    w.section("1. Очистка")
    w.add("USE `world`;\n")
    w.add("DELETE FROM `creature_loot_template` WHERE `Entry` BETWEEN %d AND %d;"
          % (BOSS_BASE, BOSS_BASE + 99))
    w.add("DELETE FROM `reference_loot_template` WHERE `Entry` BETWEEN %d AND %d;"
          % (REF_BASE + 100, REF_BASE + 199))

    w.section("2. Гарантированная награда и уникальный дроп")
    rows = []
    extra_rows = []
    total = len(BOSS_NAMES)
    for index in range(100):
        entry = BOSS_BASE + index
        essence_min = 100 + (index * 7) % 101           # 100..200
        essence_max = min(250, essence_min + 50)        # не более 250
        container = 200100 + (index * 3) % len(CONTAINERS)
        rare_one = 200400 + (index * 5) % len(RARE_ITEMS)
        rare_two = 200400 + (index * 11 + 7) % len(RARE_ITEMS)
        rare_three = 200400 + (index * 17 + 13) % len(RARE_ITEMS)
        sphere = PROFESSIONS[index % len(PROFESSIONS)][2]

        rows.append("(%d,%d,0,100,0,1,0,%d,%d,%s)" % (
            entry, ESSENCE, essence_min, essence_max,
            sql_str("Сущность: гарантированная награда %d-%d" % (essence_min, essence_max))))
        rows.append("(%d,%d,0,100,0,1,0,1,1,%s)" % (
            entry, container, sql_str("Ящик с ресурсами")))
        rows.append("(%d,%d,0,3.5,0,1,1,1,1,%s)" % (
            entry, rare_one, sql_str("Редкий предмет LEGIONFORGE")))
        rows.append("(%d,%d,0,1.5,0,1,1,1,1,%s)" % (
            entry, rare_two, sql_str("Редкий предмет LEGIONFORGE")))
        rows.append("(%d,%d,0,0.6,0,1,1,1,1,%s)" % (
            entry, rare_three, sql_str("Уникальный предмет LEGIONFORGE")))
        rows.append("(%d,%d,0,12,0,1,2,1,3,%s)" % (
            entry, sphere, sql_str("Токен улучшения")))

        ref = REF_BASE + 100 + index
        extra_rows.append("(%d,%d,0,100,0,1,0,1,1,%s)" % (
            ref, ESSENCE, sql_str("Дополнительная сущность")))
        extra_rows.append("(%d,%d,0,25,0,1,0,1,1,%s)" % (
            ref, container, sql_str("Дополнительный ящик")))
        rows.append("(%d,0,%d,20,0,1,3,1,1,%s)" % (
            entry, ref, sql_str("Бонусный набор мини-босса")))

    w.add("INSERT INTO `creature_loot_template` (`Entry`,`Item`,`Reference`,"
          "`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,"
          "`MaxCount`,`Comment`) VALUES")
    w.add(",\n".join(rows) + ";")
    w.add("")
    w.add("INSERT INTO `reference_loot_template` (`Entry`,`Item`,`Reference`,"
          "`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,"
          "`MaxCount`,`Comment`) VALUES")
    w.add(",\n".join(extra_rows) + ";")
    w.save(path)


# --------------------------------------------------------------------------
# Генерация sql/43_legionforge_upgrade_tokens.sql
# --------------------------------------------------------------------------

def build_upgrades(path):
    w = Writer("LEGIONFORGE 7.3.5 - система улучшения предметов\n"
               "Файл: sql/43_legionforge_upgrade_tokens.sql\n"
               "Легендарные предметы: 1000 -> 1200 ilvl шагом +5\n"
               "Экипировка профессий: до 985 ilvl, затем 985 -> 1000 ilvl")
    w.section("1. Расширенная стоимость предметов")
    w.add("USE `hotfixes`;\n")
    w.add("DELETE FROM `item_extended_cost` WHERE `ID` BETWEEN %d AND %d;"
          % (COST_BASE, COST_BASE + 3999))

    cost_rows = []
    cost_index = 0

    # Цепочка улучшений легендарных предметов
    legendary_cost = {}
    for base_index, (base_name, base_ilvl, inv_slot, quality, sub, kind) in enumerate(LEGENDARY_BASES):
        previous = 200500 + base_index
        tier = 0
        ilvl = base_ilvl + LEGENDARY_STEP
        while ilvl <= LEGENDARY_MAX:
            tier += 1
            current = 200510 + base_index * 100 + tier
            cost_index += 1
            cost_id = COST_BASE + cost_index
            legendary_cost[current] = cost_id
            essence_cost = 250 + tier * 25
            sphere_cost = 2 + tier
            cost_rows.append(ext_cost_row(cost_id, previous, SPHERE, ESSENCE,
                                          1, sphere_cost, essence_cost))
            previous = current
            ilvl += LEGENDARY_STEP

    # Цепочка улучшений экипировки профессий
    crafted_cost = {}
    for base_index, (base_name, base_ilvl, inv_slot, quality, sub, skill_id, prof_name) in enumerate(CRAFTED_BASES):
        previous = 200700 + base_index
        tier = 0
        ilvl = base_ilvl + CRAFTED_STEP
        while ilvl <= CRAFTED_MAX:
            tier += 1
            current = 200710 + base_index * 100 + tier
            cost_index += 1
            cost_id = COST_BASE + cost_index
            crafted_cost[current] = cost_id
            essence_cost = 150 + tier * 20
            sphere_cost = 1 + tier
            cost_rows.append(ext_cost_row(cost_id, previous, SPHERE, ESSENCE,
                                          1, sphere_cost, essence_cost))
            previous = current
            ilvl += CRAFTED_STEP

    w.add("INSERT INTO `item_extended_cost` (`ID`,`RequiredItem1`,"
          "`RequiredItem2`,`RequiredItem3`,`RequiredItem4`,`RequiredItem5`,"
          "`RequiredCurrencyCount1`,`RequiredCurrencyCount2`,"
          "`RequiredCurrencyCount3`,`RequiredCurrencyCount4`,"
          "`RequiredCurrencyCount5`,`RequiredItemCount1`,`RequiredItemCount2`,"
          "`RequiredItemCount3`,`RequiredItemCount4`,`RequiredItemCount5`,"
          "`RequiredPersonalArenaRating`,`RequiredCurrency1`,"
          "`RequiredCurrency2`,`RequiredCurrency3`,`RequiredCurrency4`,"
          "`RequiredCurrency5`,`RequiredArenaSlot`,`RequiredFactionId`,"
          "`RequiredFactionStanding`,`RequirementFlags`,`RequiredAchievement`,"
          "`VerifiedBuild`) VALUES")
    w.add(",\n".join(cost_rows) + ";")

    w.section("2. Расширенная стоимость токенов профессий")
    rows = []
    for skill_id, prof_name, token_id, token_name, reagents in PROFESSIONS:
        cost_index += 1
        cost_id = COST_BASE + cost_index
        items = ["0"] * 5
        counts = ["0"] * 5
        for position, (rid, amount, rname) in enumerate(reagents[:5]):
            items[position] = str(rid)
            counts[position] = str(amount)
        vals = ([cost_id] + items + [0, 0, 0, 0, 0] + counts +
                [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, VERIFIED])
        assert len(vals) == 28, len(vals)
        rows.append("(" + ",".join(str(v) for v in vals) + ")")
    w.add("")
    w.add("INSERT INTO `item_extended_cost` (`ID`,`RequiredItem1`,"
          "`RequiredItem2`,`RequiredItem3`,`RequiredItem4`,`RequiredItem5`,"
          "`RequiredCurrencyCount1`,`RequiredCurrencyCount2`,"
          "`RequiredCurrencyCount3`,`RequiredCurrencyCount4`,"
          "`RequiredCurrencyCount5`,`RequiredItemCount1`,`RequiredItemCount2`,"
          "`RequiredItemCount3`,`RequiredItemCount4`,`RequiredItemCount5`,"
          "`RequiredPersonalArenaRating`,`RequiredCurrency1`,"
          "`RequiredCurrency2`,`RequiredCurrency3`,`RequiredCurrency4`,"
          "`RequiredCurrency5`,`RequiredArenaSlot`,`RequiredFactionId`,"
          "`RequiredFactionStanding`,`RequirementFlags`,`RequiredAchievement`,"
          "`VerifiedBuild`) VALUES")
    w.add(",\n".join(rows) + ";")

    w.section("3. Вендоры Даларана")
    w.add("USE `world`;\n")
    w.add("DELETE FROM `npc_vendor` WHERE `entry` IN (%d,%d,%d,%d);"
          % (VENDOR_BOSS, VENDOR_UPGRADE, VENDOR_KNOWLEDGE, VENDOR_LEGENDARY))
    w.add("DELETE FROM `creature_template` WHERE `entry` BETWEEN %d AND %d;"
          % (VENDOR_BOSS, VENDOR_LEGENDARY))
    w.add("DELETE FROM `creature` WHERE `guid` BETWEEN %d AND %d;"
          % (SPAWN_BASE + 100, SPAWN_BASE + 103))
    w.add("DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 25"
          " AND `SourceGroup` IN (%d,%d,%d,%d);"
          % (VENDOR_BOSS, VENDOR_UPGRADE, VENDOR_KNOWLEDGE, VENDOR_LEGENDARY))
    w.add("")

    vendors = [
        (VENDOR_BOSS, "Хранитель трофеев", "Торговец LEGIONFORGE", -828.8, 4371.9, 738.6),
        (VENDOR_UPGRADE, "Мастер улучшений", "Улучшение экипировки", -824.0, 4366.0, 738.6),
        (VENDOR_KNOWLEDGE, "Хранитель знаний", "Древнее знание", -819.0, 4361.0, 738.6),
        (VENDOR_LEGENDARY, "Торговец легендарных предметов", "Легендарные предметы", -814.0, 4356.0, 738.6),
    ]
    rows = []
    for vid, name, sub, x, y, z in vendors:
        rows.append("(%d,%s,'',%s,110,110,6,6,35,129,1,1.14286,1,0,0,2000,2000,"
                    "1,1,2,7,0,0,0,'',0,10,1,1,1,1,1,0,0,'',%d)"
                    % (vid, sql_str(name), sql_str(sub), VERIFIED))
    w.add("INSERT INTO `creature_template` (`entry`,`name`,`femaleName`,"
          "`subname`,`minlevel`,`maxlevel`,`HealthScalingExpansion`,"
          "`RequiredExpansion`,`faction`,`npcflag`,`speed_walk`,`speed_run`,"
          "`scale`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,"
          "`BaseVariance`,`RangeVariance`,`unit_class`,`type`,`lootid`,"
          "`mingold`,`maxgold`,`AIName`,`MovementType`,`HealthModifier`,"
          "`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,"
          "`RegenHealth`,`mechanic_immune_mask`,`flags_extra`,`ScriptName`,"
          "`VerifiedBuild`) VALUES")
    w.add(",\n".join(rows) + ";")
    w.add("")
    rows = []
    for index, (vid, name, sub, x, y, z) in enumerate(vendors):
        rows.append("(%d,%d,1220,7502,7502,1,0,0,0,0,%.3f,%.3f,%.3f,0.7854,"
                    "300,0,0,1,0,0,'',%d)"
                    % (SPAWN_BASE + 100 + index, vid, x, y, z, VERIFIED))
    w.add("INSERT INTO `creature` (`guid`,`id`,`map`,`zoneId`,`areaId`,"
          "`spawnMask`,`PhaseId`,`PhaseGroup`,`modelid`,`equipment_id`,"
          "`position_x`,`position_y`,`position_z`,`orientation`,"
          "`spawntimesecs`,`spawndist`,`currentwaypoint`,`curhealth`,"
          "`curmana`,`MovementType`,`ScriptName`,`VerifiedBuild`) VALUES")
    w.add(",\n".join(rows) + ";")

    w.section("4. Ассортимент Мастера улучшений")
    rows = []
    slot = 0
    for item_id, cost_id in sorted(legendary_cost.items()):
        slot += 1
        rows.append("(%d,%d,%d,0,0,%d,1,'',0,0,%d)"
                    % (VENDOR_UPGRADE, slot, item_id, cost_id, VERIFIED))
    for item_id, cost_id in sorted(crafted_cost.items()):
        slot += 1
        rows.append("(%d,%d,%d,0,0,%d,1,'',0,0,%d)"
                    % (VENDOR_UPGRADE, slot, item_id, cost_id, VERIFIED))
    w.add("INSERT INTO `npc_vendor` (`entry`,`slot`,`item`,`maxcount`,"
          "`incrtime`,`ExtendedCost`,`type`,`BonusListIDs`,`PlayerConditionID`,"
          "`IgnoreFiltering`,`VerifiedBuild`) VALUES")
    w.add(",\n".join(rows) + ";")

    w.section("5. Ассортимент Хранителя трофеев (токены профессий)")
    rows = []
    for index, (skill_id, prof_name, token_id, token_name, reagents) in enumerate(PROFESSIONS):
        rows.append("(%d,%d,%d,0,0,%d,1,'',0,0,%d)"
                    % (VENDOR_BOSS, index + 1, token_id,
                       COST_BASE + len(legendary_cost) + len(crafted_cost) + index + 1, VERIFIED))
    rows.append("(%d,%d,%d,0,0,0,1,'',0,0,%d)" % (VENDOR_BOSS, 50, SPHERE, VERIFIED))
    w.add("INSERT INTO `npc_vendor` (`entry`,`slot`,`item`,`maxcount`,"
          "`incrtime`,`ExtendedCost`,`type`,`BonusListIDs`,`PlayerConditionID`,"
          "`IgnoreFiltering`,`VerifiedBuild`) VALUES")
    w.add(",\n".join(rows) + ";")

    w.section("6. Ограничение токенов по профессии")
    w.add("-- Токен доступен только мастеру соответствующей профессии")
    w.add("-- (SourceTypeOrReferenceId = 25 - NPC_VENDOR).")
    rows = []
    for index, (skill_id, prof_name, token_id, token_name, reagents) in enumerate(PROFESSIONS):
        rows.append("(25,%d,%d,0,0,7,0,%d,%d,0,0,0,0,'',%s)" % (
            VENDOR_BOSS, token_id, skill_id, PROFESSION_SKILL_MIN,
            sql_str("Требуется профессия «%s» не ниже %d" % (prof_name, PROFESSION_SKILL_MIN))))
    w.add("INSERT INTO `conditions` (`SourceTypeOrReferenceId`,`SourceGroup`,"
          "`SourceEntry`,`SourceId`,`ElseGroup`,`ConditionTypeOrReference`,"
          "`ConditionTarget`,`ConditionValue1`,`ConditionValue2`,"
          "`ConditionValue3`,`NegativeCondition`,`ErrorType`,`ErrorTextId`,"
          "`ScriptName`,`Comment`) VALUES")
    w.add(",\n".join(rows) + ";")
    w.save(path)


# --------------------------------------------------------------------------
# Генерация sql/44_legionforge_upgrade_limits.sql
# --------------------------------------------------------------------------

def build_limits(path):
    w = Writer("LEGIONFORGE 7.3.5 - пределы улучшения экипировки\n"
               "Файл: sql/44_legionforge_upgrade_limits.sql\n"
               "Легендарные предметы: максимум %d ilvl\n"
               "Экипировка профессий: %d ilvl и переход %d -> %d"
               % (LEGENDARY_MAX, 985, 985, CRAFTED_MAX))
    w.section("1. Правила улучшения")
    w.add("USE `world`;\n")
    w.add("CREATE TABLE IF NOT EXISTS `legionforge_upgrade_rules` (")
    w.add("  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,")
    w.add("  `rule_name` VARCHAR(100) NOT NULL,")
    w.add("  `item_class` VARCHAR(60) NOT NULL,")
    w.add("  `min_item_level` SMALLINT UNSIGNED NOT NULL DEFAULT 0,")
    w.add("  `max_item_level` SMALLINT UNSIGNED NOT NULL DEFAULT 0,")
    w.add("  `step` SMALLINT UNSIGNED NOT NULL DEFAULT 5,")
    w.add("  `token_id` INT UNSIGNED NOT NULL DEFAULT 0,")
    w.add("  `token_count_base` INT UNSIGNED NOT NULL DEFAULT 1,")
    w.add("  `essence_count_base` INT UNSIGNED NOT NULL DEFAULT 100,")
    w.add("  `comment` VARCHAR(255) DEFAULT NULL,")
    w.add("  PRIMARY KEY (`id`),")
    w.add("  UNIQUE KEY `uk_rule` (`rule_name`)")
    w.add(") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
          " COMMENT='Правила улучшения предметов LEGIONFORGE';")
    w.add("")
    w.add("DELETE FROM `legionforge_upgrade_rules`;")
    rows = [
        "(NULL,'Легендарное оружие','Оружие',1000,%d,%d,%d,2,250,"
        "'Улучшение легендарного оружия шагом +5')" % (LEGENDARY_MAX, LEGENDARY_STEP, SPHERE),
        "(NULL,'Легендарная броня','Броня',1000,%d,%d,%d,2,250,"
        "'Улучшение легендарной брони шагом +5')" % (LEGENDARY_MAX, LEGENDARY_STEP, SPHERE),
        "(NULL,'Легендарные аксессуары','Кольца, плащи, тринкеты',1000,%d,%d,%d,2,250,"
        "'Улучшение легендарных аксессуаров шагом +5')" % (LEGENDARY_MAX, LEGENDARY_STEP, SPHERE),
        "(NULL,'Экипировка кожевника','Кожа',950,985,%d,%d,1,150,"
        "'Верхняя ступень кожевничества - 985 ilvl')" % (CRAFTED_STEP, SPHERE),
        "(NULL,'Экипировка кузнеца','Латы и кольчуга',950,985,%d,%d,1,150,"
        "'Верхняя ступень кузнечного дела - 985 ilvl')" % (CRAFTED_STEP, SPHERE),
        "(NULL,'Экипировка портного','Ткань',950,985,%d,%d,1,150,"
        "'Верхняя ступень портняжного дела - 985 ilvl')" % (CRAFTED_STEP, SPHERE),
        "(NULL,'Переход 985 -> 1000','Любая экипировка профессий',985,%d,%d,%d,3,300,"
        "'Особая ступень улучшения 985 до 1000 ilvl')"
        % (CRAFTED_MAX, CRAFTED_STEP, SPHERE),
    ]
    w.add("INSERT INTO `legionforge_upgrade_rules` (`id`,`rule_name`,"
          "`item_class`,`min_item_level`,`max_item_level`,`step`,`token_id`,"
          "`token_count_base`,`essence_count_base`,`comment`) VALUES")
    w.add(",\n".join(rows) + ";")

    w.section("2. Бонусные списки изменения уровня предмета")
    w.add("USE `hotfixes`;\n")
    w.add("DELETE FROM `item_bonus_list_level_delta` WHERE `ID` BETWEEN 400000 AND 400399;")
    rows = []
    for tier in range(1, 41):
        delta = tier * 5
        rows.append("(%d,%d,%d)" % (400000 + tier, delta, VERIFIED))
    w.add("INSERT INTO `item_bonus_list_level_delta` (`ID`,`Delta`,"
          "`VerifiedBuild`) VALUES")
    w.add(",\n".join(rows) + ";")
    w.save(path)


# --------------------------------------------------------------------------
# Генерация sql/45_legionforge_ancient_knowledge.sql
# --------------------------------------------------------------------------

def build_knowledge(path):
    w = Writer("LEGIONFORGE 7.3.5 - восстановленные способности классов\n"
               "Файл: sql/45_legionforge_ancient_knowledge.sql\n"
               "Свиток «Древнее знание» стоит 100000 единиц «Сущность»")
    w.section("1. Расширенная стоимость свитков")
    w.add("USE `hotfixes`;\n")
    w.add("DELETE FROM `item_extended_cost` WHERE `ID` BETWEEN %d AND %d;"
          % (COST_BASE + 2000, COST_BASE + 2099))
    rows = []
    for index, (ability, spell_id, class_id, desc) in enumerate(ANCIENT_KNOWLEDGE):
        rows.append(ext_cost_row(COST_BASE + 2000 + index, ESSENCE, 0, 0, 100000, 0, 0))
    w.add("INSERT INTO `item_extended_cost` (`ID`,`RequiredItem1`,"
          "`RequiredItem2`,`RequiredItem3`,`RequiredItem4`,`RequiredItem5`,"
          "`RequiredCurrencyCount1`,`RequiredCurrencyCount2`,"
          "`RequiredCurrencyCount3`,`RequiredCurrencyCount4`,"
          "`RequiredCurrencyCount5`,`RequiredItemCount1`,`RequiredItemCount2`,"
          "`RequiredItemCount3`,`RequiredItemCount4`,`RequiredItemCount5`,"
          "`RequiredPersonalArenaRating`,`RequiredCurrency1`,"
          "`RequiredCurrency2`,`RequiredCurrency3`,`RequiredCurrency4`,"
          "`RequiredCurrency5`,`RequiredArenaSlot`,`RequiredFactionId`,"
          "`RequiredFactionStanding`,`RequirementFlags`,`RequiredAchievement`,"
          "`VerifiedBuild`) VALUES")
    w.add(",\n".join(rows) + ";")

    w.section("2. Ассортимент Хранителя знаний")
    w.add("USE `world`;\n")
    w.add("DELETE FROM `npc_vendor` WHERE `entry` = %d;" % VENDOR_KNOWLEDGE)
    rows = []
    for index, (ability, spell_id, class_id, desc) in enumerate(ANCIENT_KNOWLEDGE):
        rows.append("(%d,%d,%d,0,0,%d,1,'',0,0,%d)"
                    % (VENDOR_KNOWLEDGE, index + 1, 200200 + index,
                       COST_BASE + 2000 + index, VERIFIED))
    w.add("INSERT INTO `npc_vendor` (`entry`,`slot`,`item`,`maxcount`,"
          "`incrtime`,`ExtendedCost`,`type`,`BonusListIDs`,`PlayerConditionID`,"
          "`IgnoreFiltering`,`VerifiedBuild`) VALUES")
    w.add(",\n".join(rows) + ";")

    w.section("3. Ограничение по классу персонажа")
    w.add("DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 25"
          " AND `SourceGroup` = %d;" % VENDOR_KNOWLEDGE)
    rows = []
    for index, (ability, spell_id, class_id, desc) in enumerate(ANCIENT_KNOWLEDGE):
        if class_id == 0:
            continue
        rows.append("(25,%d,%d,0,0,15,0,%d,0,0,0,0,0,'',%s)"
                    % (VENDOR_KNOWLEDGE, 200200 + index, class_id,
                       sql_str("Только для класса %d: %s" % (class_id, ability))))
    w.add("INSERT INTO `conditions` (`SourceTypeOrReferenceId`,`SourceGroup`,"
          "`SourceEntry`,`SourceId`,`ElseGroup`,`ConditionTypeOrReference`,"
          "`ConditionTarget`,`ConditionValue1`,`ConditionValue2`,"
          "`ConditionValue3`,`NegativeCondition`,`ErrorType`,`ErrorTextId`,"
          "`ScriptName`,`Comment`) VALUES")
    w.add(",\n".join(rows) + ";")
    w.save(path)


# --------------------------------------------------------------------------
# Генерация sql/46_legionforge_playerbots.sql и 47_legionforge_admin.sql
# --------------------------------------------------------------------------

def build_bots(path):
    w = Writer("LEGIONFORGE 7.3.5 - игровая бот-система (PlayerBot)\n"
               "Файл: sql/46_legionforge_playerbots.sql\n"
               "Боты управляются ядром: core/src/server/game/PlayerBot и\n"
               "core/src/server/game/AI/PlayerAI. Служебные таблицы aiwaypoints.")
    w.section("1. Точки патрулирования ботов")
    w.add("USE `world`;\n")
    w.add("CREATE TABLE IF NOT EXISTS `aiwaypoints` (")
    w.add("  `entry` INT UNSIGNED NOT NULL AUTO_INCREMENT,")
    w.add("  `map` INT UNSIGNED NOT NULL DEFAULT 0,")
    w.add("  `position_x` FLOAT NOT NULL DEFAULT 0,")
    w.add("  `position_y` FLOAT NOT NULL DEFAULT 0,")
    w.add("  `position_z` FLOAT NOT NULL DEFAULT 0,")
    w.add("  `link` TEXT,")
    w.add("  `comment` TEXT,")
    w.add("  PRIMARY KEY (`entry`)")
    w.add(") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;")
    w.add("")
    w.add("DELETE FROM `aiwaypoints` WHERE `comment` LIKE 'LEGIONFORGE%';")
    rows = []
    points = [
        (1220, -828.835, 4371.91, 738.636, "Даларан, площадь"),
        (1220, -824.0, 4366.0, 738.6, "Даларан, ряд вендоров"),
        (1220, -819.0, 4361.0, 738.6, "Даларан, ряд вендоров"),
        (1220, -814.0, 4356.0, 738.6, "Даларан, ряд вендоров"),
        (0, -8833.0, 628.0, 94.0, "Штормград, торговая площадь"),
        (0, -8949.95, -132.493, 83.5312, "Штормград, ворота"),
        (1, 1629.85, -4373.53, 31.2564, "Оргриммар, главные ворота"),
        (1, 1676.71, -4318.66, 61.7729, "Оргриммар, долина силы"),
    ]
    for index, (map_id, x, y, z, comment) in enumerate(points):
        rows.append("(%d,%d,%.4f,%.4f,%.4f,'',%s)"
                    % (index + 1, map_id, x, y, z,
                       sql_str("LEGIONFORGE: %s" % comment)))
    w.add("INSERT INTO `aiwaypoints` (`entry`,`map`,`position_x`,"
          "`position_y`,`position_z`,`link`,`comment`) VALUES")
    w.add(",\n".join(rows) + ";")
    w.save(path)


def build_admin(path):
    w = Writer("LEGIONFORGE 7.3.5 - учётная запись администратора\n"
               "Файл: sql/47_legionforge_admin.sql\n"
               "Логин: admin@legionforge.ru   Пароль: legionforge")
    w.section("1. Игровая учётная запись")
    w.add("USE `auth`;\n")
    w.add("-- Пароль передаётся через формулу MySQL SHA1(UPPER(user):PASS),"
          " поэтому хэш не зашит в файл.")
    w.add("SET @lf_user = 'ADMIN';")
    w.add("SET @lf_pass = 'LEGIONFORGE';")
    w.add("SET @lf_hash = UPPER(SHA1(CONCAT(@lf_user, ':', @lf_pass)));")
    w.add("")
    w.add("INSERT INTO `account` (`username`,`sha_pass_hash`,`email`,"
          "`reg_mail`,`joindate`,`last_ip`,`last_attempt_ip`,`failed_logins`,"
          "`locked`,`lock_country`,`online`,`expansion`,`mutetime`,`mutereason`,"
          "`mutby`,`locale`,`os`,`recruiter`)")
    w.add("SELECT @lf_user, @lf_hash, 'admin@legionforge.ru',"
          " 'admin@legionforge.ru', NOW(), '127.0.0.1', '127.0.0.1', 0, 0,"
          " '00', 0, 6, 0, '', '', 0, 'Win', 0")
    w.add("WHERE NOT EXISTS (SELECT 1 FROM `account` WHERE `username` = @lf_user);")
    w.add("")
    w.add("UPDATE `account` SET `sha_pass_hash` = @lf_hash,"
          " `email` = 'admin@legionforge.ru', `reg_mail` = 'admin@legionforge.ru',"
          " `expansion` = 6 WHERE `username` = @lf_user;")
    w.add("")
    w.add("-- Уровень доступа 3 (администратор).")
    w.add("DELETE FROM `account_access` WHERE `id` ="
          " (SELECT `id` FROM `account` WHERE `username` = @lf_user);")
    w.add("INSERT INTO `account_access` (`id`,`SecurityLevel`,`RealmID`)")
    w.add("SELECT `id`, 3, -1 FROM `account` WHERE `username` = @lf_user;")
    w.add("")
    w.add("-- Учётная запись Battle.net создаётся скриптом create_admin.bat,")
    w.add("-- так как её хэш зависит от выбранного алгоритма шифрования.")
    w.save(path)


# --------------------------------------------------------------------------
# Точка входа
# --------------------------------------------------------------------------

def main():
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", ".."))
    sql_dir = os.path.join(root, "sql")
    if not os.path.isdir(sql_dir):
        os.makedirs(sql_dir)
    build_items(os.path.join(sql_dir, "40_legionforge_items.sql"))
    build_bosses(os.path.join(sql_dir, "41_legionforge_minibosses.sql"))
    build_loot(os.path.join(sql_dir, "42_legionforge_miniboss_loot.sql"))
    build_upgrades(os.path.join(sql_dir, "43_legionforge_upgrade_tokens.sql"))
    build_limits(os.path.join(sql_dir, "44_legionforge_upgrade_limits.sql"))
    build_knowledge(os.path.join(sql_dir, "45_legionforge_ancient_knowledge.sql"))
    build_bots(os.path.join(sql_dir, "46_legionforge_playerbots.sql"))
    build_admin(os.path.join(sql_dir, "47_legionforge_admin.sql"))
    print("SQL-патчи LEGIONFORGE сформированы в каталоге:", sql_dir)


if __name__ == "__main__":
    main()
