# workerd-patch — workerd с лимитами CPU и памяти

Своя сборка workerd для sites-host. План и причины — `runtime-host/WORKERD_LIMITS_PLAN.md`.

| Файл | Что это |
|---|---|
| `VERSION` | тег релиза cloudflare/workerd, на который накладываются патчи |
| `patches/0001-tenant-limits.patch` | ограничители CPU, кучи V8 и памяти ArrayBuffer (`src/workerd/server/factory/tenant-limits.{h,c++}`) и их подключение в `worker-factory.c++` |
| `Dockerfile` | образ с инструментами как у upstream: Debian trixie, LLVM 22, Bazel (bazelisk), pnpm |
| `build.sh`, `build-in-container.sh` | сборка: исходники и кэш Bazel — в томах Docker `workerd-src` и `workerd-bazel` |

## Сборка

```bash
sh runtime-host/workerd-patch/build.sh
```

Бинарь — `runtime-host/workerd-patch/out/workerd` (Linux x86_64, glibc trixie, 166 МБ).

- Первая сборка компилирует V8: 80–120 минут на 8 ядрах (`--jobs=6`).
- Исходники и кэш Bazel лежат в именованных томах `workerd-src` и `workerd-bazel`, поэтому правка патча пересобирает только изменённое: ~75 секунд. Новая версия workerd с другим V8 — снова полная сборка.
- Кэш BuildKit (`--mount=type=cache`) не подходит: он терял кэш между сборками.
- Не хватает памяти — `BAZEL_ARGS="--jobs=4" sh build.sh`. Начать с нуля — `docker volume rm workerd-src workerd-bazel`.

## Сборка в CI (релизные бинари)

Папка целиком лежит и в публичном репозитории https://github.com/vlnifos/fromflow-workerd — там `.github/workflows/build.yml` собирает её на бесплатных раннерах GitHub под **Linux arm64 и x86_64** (4 ядра, 16 ГБ, без кэша — каждый раз V8 с нуля, 2,5–4 ч) и выкладывает релиз `<VERSION>-ff.<хэш патчей>` с `workerd-linux-arm64.gz`, `workerd-linux-x64.gz` и их sha256.

- Запуск: push в `main` с изменением `VERSION` или патчей, или руками — Actions → build workerd → Run workflow.
- Локальная сборка (`build.sh`) остаётся для правки патча: ~75 с с кэшем; в CI — только релиз.
- Код в монорепозитории — источник правды; в публичный репозиторий его копируют (сам по себе он там не меняется).

## Включение

Без переменных окружения бинарь ведёт себя как upstream. Лимиты включаются так:

| Переменная | Что ограничивает |
|---|---|
| `WORKERD_TENANT_CPU_MS` | процессорное время одного запроса (все входы в JS за запрос) |
| `WORKERD_TENANT_STARTUP_CPU_MS` | старт скрипта и динамические импорты, по умолчанию 1000 |
| `WORKERD_TENANT_HEAP_MB` | кучу V8 одного изолята (= одного сайта) |
| `WORKERD_TENANT_BUFFERS_MB` | память ArrayBuffer одного изолята, по умолчанию равна куче |

Что происходит при превышении:
- **CPU** — запрос получает «Worker exceeded CPU time limit.», изолят живёт дальше;
- **куча** — JS останавливается, изолят помечается: все следующие запросы к нему получают «Worker exceeded memory limit.» (освобождает его переработка шарда);
- **ArrayBuffer** — выделение отказывает (`RangeError: Array buffer allocation failed`), изолят живёт дальше.

## Обновление workerd

1. Поменять `VERSION`.
2. `git clone --depth 1 --branch <тег> https://github.com/cloudflare/workerd.git` и `git apply --check patches/*.patch`.
3. Если не накладывается — перенести правку руками (она в двух местах `worker-factory.c++` рядом с `NullLimitEnforcer` и `NullIsolateLimitEnforcer`), пересохранить патч `git diff > patches/0001-tenant-limits.patch`.
4. Собрать и прогнать стенд `runtime-host/sites-p0` (раздел «Своя сборка workerd» в его README).
