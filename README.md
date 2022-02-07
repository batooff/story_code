## Про себя
Привет я Виталь, веду разработку с 2016 года преимущественно на ruby. \
Последние время стал замечать что все меньше стал писать код, а большую часть времени провожу на встречах или \
разруливаем разных ситуаций, начиная с помощи члену команды заканчивая консультации маркетологу. \
Люблю делать что-то своими руками, реализовать идеи и мысли в коде, есть постоянное желание учиться и развиваться. \
Начал активно заниматься поиском такой компании где я уверенно смогу развивать профессиональные умения и приносить пользу.



# Немного про примеры кода
## Пару слов про текущий проект
Давольно уже старый проект, по выдаче займов клиентам. 
В основе всех процессов лежит заявка (application).
Пользователь шага за шагом заполняет персональные данные, далее в фоновых процессах происходит \
обогащение пользовательских данных данными со сторонних сервисов, чтобы принять решение о выдаче займа клиенту.
Сложностть проекта в часто меняющихся бизнес требованиях, которые могут поменяться буквально перед релизом.\
Жизненный цикл практически любого компонента стоит из следующих вех:
- Написать удобный приятный, сервис
- Встроить вчера костыль в сервис, который вносит существенный корректив в бизнес-логику
- ... повторить пункт выше N раз
- Создать таску на рефакторинг, положить в бэклог, и надеится что таска пойдет в работу раньше чем через полгода

## Пример 1 FetchService
https://github.com/batooff/story_code/blob/master/1/fetch_service.rb \
\
Сервис помогает в принятии решения по займу. 
Собирает информацию на основе истоических данных в БД сравнивая их с данными из анкеты текущего клиента.
Севис собирает кол-во найденных совдений по указанным полям акеты на определнный срок (за час, 7-14-30 дней)

## Пример 2 DocumentRecognition
https://github.com/batooff/story_code/blob/master/2/document_recognition_index_worker.rb - после исправления бага \
https://github.com/batooff/story_code/blob/master/2/document_recognition_index_worker_old.rb - оригинальный код \
\
Сервис писался вендором. Часто приходится что-то быстро фиксить, и редко это мой код. Я это не к тому что не допускаю \
ошибки, у меня редко есть возможность разработки с нуля или от начала и до конца.\
Короче.. в данном примере просходит распознование загруженных пользователем изоборажений и сохранение их в коллекции amazon \
Самая важная для бизнеса на изображения это лица. Информация сохраняется в постоянную коллекцию и во временную\
для последующего сравнения лиц между собой, позже временная коллекция удаляется.\
Моя задача была найти и справить ситуацию при которой, если на документе было найдено одно лицо, а должно быть два и \
данные не записывались вовсе. Попутно нужно было сделать рефакторинг 'полуфабрикат' \ 
для того чтобы команде было проще далее сопровозждать код или сделать полный рефакторинг.
