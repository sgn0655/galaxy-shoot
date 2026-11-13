
import java.util.ArrayList;

// =====================================
// 3D SPACE SHOOTER
// SHIFT PERFECT PARRY EDITION
// Processing Java Mode / P3D
// =====================================

ArrayList<Enemy> enemies = new ArrayList<Enemy>();
ArrayList<Shot> shots = new ArrayList<Shot>();
ArrayList<Spark> sparks = new ArrayList<Spark>();
ArrayList<Star> stars = new ArrayList<Star>();

final float ENEMY_Z = -560;
final float MIN_ENEMY_Y = -105;
final float MAX_ENEMY_Y = 105;

final int GRID = 0;
final int V_FORM = 1;
final int WAVE = 2;
final int RING = 3;

// 60FPS 기준
final int PARRY_WINDOW = 7;       // 약 0.12초
final int PARRY_FAIL_COOLDOWN = 78; // 1.3초

float px = 0;
float py = 90;
final float pz = 220;
float playerSpeed = 5.5;

int score = 0;
int lives = 3;
int wave = 1;

// 0 시작, 1 플레이, 2 게임오버, 3 일시정지
int state = 0;

int tick = 0;
int currentPattern = GRID;
int lastPattern = -1;

int enemyDir = 1;
float enemySpeed = 1.5;

int fireCooldown = 0;
int enemyFireTimer = 70;
int invincible = 0;
int waveWait = -1;

// =====================================
// PARRY VARIABLES
// =====================================

int parryFrames = 0;
int parryCooldown = 0;
int parrySuccessFlash = 0;
int parryFailFlash = 0;

boolean parryHeld = false;

boolean leftKey = false;
boolean rightKey = false;
boolean upKey = false;
boolean downKey = false;
boolean fireKey = false;

float aimSX, aimSY;

// =====================================
// SETUP
// =====================================

void setup() {
  size(960, 720, P3D);
  smooth(4);
  frameRate(60);
  sphereDetail(12);

  for (int i = 0; i < 300; i++) {
    stars.add(new Star());
  }

  resetGame();
  state = 0;
}

// =====================================
// DRAW
// =====================================

void draw() {
  background(3, 5, 18);

  if (state == 1) {
    updateGame();
  } else if (state == 0 || state == 2) {
    for (Star s : stars) {
      s.update();
    }
  }

  camera(
    0, -120, 580,
    0, -5, -300,
    0, 1, 0
  );

  ambientLight(75, 85, 120);

  directionalLight(
    150, 180, 255,
    -0.4, 0.6, -1
  );

  directionalLight(
    100, 60, 130,
    0.5, -0.3, 1
  );

  drawStars();
  drawGrid();
  drawEnemies();
  drawShots();
  drawSparks();
  drawPlayer();

  // 조준선은 실제 적 전투 평면에 표시
  aimSX = screenX(px, py, ENEMY_Z);
  aimSY = screenY(px, py, ENEMY_Z);

  drawOverlay();
}

// =====================================
// RESET GAME
// =====================================

void resetGame() {
  score = 0;
  lives = 3;
  wave = 1;
  tick = 0;

  lastPattern = -1;

  px = 0;
  py = 90;

  fireCooldown = 0;
  enemyFireTimer = 70;
  invincible = 0;
  waveWait = -1;

  parryFrames = 0;
  parryCooldown = 0;
  parrySuccessFlash = 0;
  parryFailFlash = 0;
  parryHeld = false;

  leftKey = false;
  rightKey = false;
  upKey = false;
  downKey = false;
  fireKey = false;

  shots.clear();
  sparks.clear();

  createWave();
}

// =====================================
// ENEMY FIRE RATE
// =====================================

// WAVE 1  = 1.0x
// WAVE 6  = 1.5x
// WAVE 11 = 2.0x
// WAVE 16 = 2.5x
// WAVE 21 = 3.0x (MAX)

float enemyFireRate() {
  return min(
    3.0,
    1.0 + (wave - 1) * 0.1
  );
}

// 적 발사 간격을 연사 배율만큼 줄임
void scheduleEnemyShot() {
  enemyFireTimer = max(
    1,
    round(
      random(42, 85) / enemyFireRate()
    )
  );
}

// =====================================
// PARRY SYSTEM
// =====================================

// SHIFT를 새로 눌렀을 때 실행
void startParry() {

  if (state != 1) return;

  // 쿨타임이 있으면 사용 불가
  if (parryCooldown > 0) return;

  // 이미 패링 중이면 재사용 불가
  if (parryFrames > 0) return;

  // 약 0.12초의 패링 판정 시작
  parryFrames = PARRY_WINDOW;

  // 중요한 점:
// 여기서는 쿨타임을 설정하지 않음!
// 실패했을 때만 쿨타임 발생
}

// 패링 성공 처리
void perfectParry() {

  // 현재 패링 종료
  parryFrames = 0;

  // 성공 시 쿨타임 없음
  parryCooldown = 0;

  parrySuccessFlash = 25;
  parryFailFlash = 0;

  // 보너스 점수
  score += 50;

  explode(
    px, py, pz,
    color(0, 255, 255)
  );

  // 반격 레이저
  shots.add(new Shot(
    px, py, pz - 55,
    new PVector(0, 0, -60),
    true
  ));
}

// 패링 실패 처리
void failParry() {

  parryFrames = 0;

  // 실패한 경우에만 1.3초 쿨타임
  parryCooldown = PARRY_FAIL_COOLDOWN;

  parryFailFlash = 25;
}

// 패링 타이머 갱신
void updateParry() {

  if (parrySuccessFlash > 0) {
    parrySuccessFlash--;
  }

  if (parryFailFlash > 0) {
    parryFailFlash--;
  }

  // 쿨타임 계산
  if (parryCooldown > 0) {
    parryCooldown--;
  }

  // 패링 유효 시간 계산
  if (parryFrames > 0) {

    parryFrames--;

    // 패링 시간이 끝났는데
    // 방어에 성공하지 못했다면 실패
    if (parryFrames == 0) {
      failParry();
    }
  }
}

// =====================================
// CREATE WAVE
// =====================================

void createWave() {

  enemies.clear();
  shots.clear();

  enemyDir = 1;

  enemySpeed = min(
    1.2 + wave * 0.18,
    3.2
  );

  enemyFireTimer = round(
    70 / enemyFireRate()
  );

  waveWait = -1;

  // 이전 웨이브와 다른 패턴 선택
  do {
    currentPattern = int(random(4));
  } while (currentPattern == lastPattern);

  lastPattern = currentPattern;

  // GRID
  if (currentPattern == GRID) {

    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 7; col++) {

        addEnemy(
          (col - 3) * 70,
          -78 + row * 72,
          row
        );
      }
    }
  }

  // V FORM
  else if (currentPattern == V_FORM) {

    for (int i = -4; i <= 4; i++) {

      addEnemy(
        i * 55,
        -65 + abs(i) * 24,
        abs(i) % 3
      );
    }

    for (int i = -3; i <= 3; i++) {

      addEnemy(
        i * 53,
        30 + abs(i) * 22,
        (abs(i) + 1) % 3
      );
    }
  }

  // WAVE
  else if (currentPattern == WAVE) {

    for (int i = 0; i < 17; i++) {

      addEnemy(
        map(i, 0, 16, -230, 230),
        sin(i * 0.7) * 78,
        i % 3
      );
    }
  }

  // RING
  else if (currentPattern == RING) {

    for (int i = 0; i < 18; i++) {

      float a = TWO_PI * i / 18;

      Enemy e = addEnemy(
        cos(a) * 205,
        sin(a) * 86,
        i % 3
      );

      e.orbitAngle = a;
    }
  }
}

// =====================================
// SPAWN ENEMY
// =====================================

Enemy addEnemy(float tx, float ty, int type) {

  float sx, sy, sz;

  int mode = int(random(3));

  if (mode == 0) {

    // 먼 정면에서 진입
    sx = tx * 1.8;
    sy = ty + random(-90, 90);
    sz = -2300 - random(400);

  } else if (mode == 1) {

    // 좌우 화면 밖에서 진입
    sx = random(1) < 0.5 ? -850 : 850;
    sy = ty + random(-80, 80);
    sz = -1900 - random(400);

  } else {

    // 대각선 방향에서 진입
    sx = tx + random(-500, 500);
    sy = ty + random(-120, 120);
    sz = -2600;
  }

  Enemy e = new Enemy(sx, sy, sz, type);

  e.setTarget(tx, ty);
  enemies.add(e);

  return e;
}

// =====================================
// GAME UPDATE
// =====================================

void updateGame() {

  tick++;

  // 플레이어 이동
  if (leftKey) px -= playerSpeed;
  if (rightKey) px += playerSpeed;
  if (upKey) py -= playerSpeed;
  if (downKey) py += playerSpeed;

  px = constrain(px, -280, 280);
  py = constrain(py, -125, 135);

  // 플레이어 공격
  if (fireCooldown > 0) {
    fireCooldown--;
  }

  if (fireKey && fireCooldown == 0) {

    shots.add(new Shot(
      px, py, pz - 55,
      new PVector(0, 0, -52),
      true
    ));

    fireCooldown = 9;
  }

  if (invincible > 0) {
    invincible--;
  }

  updateEnemies();

  // 먼저 충돌 검사
  // 여기서 패링 성공 여부 결정
  updateShots();

  // 그 다음 패링 시간 계산
  updateParry();

  updateSparks();

  for (Star s : stars) {
    s.update();
  }

  // 다음 웨이브
  if (state == 1 && enemies.size() == 0) {

    if (waveWait == -1) {

      waveWait = 100;
      score += 250;

    } else {

      waveWait--;

      if (waveWait <= 0) {
        wave++;
        createWave();
      }
    }
  }
}

// =====================================
// PLAYER SHIP
// =====================================

void drawPlayer() {

  // 패링 방어막
  if (parryFrames > 0) {

    pushMatrix();
    translate(px, py, pz);

    noFill();

    stroke(0, 255, 255, 190);
    strokeWeight(2);

    sphere(48);

    noStroke();
    popMatrix();
  }

  // 패링 성공 후 짧은 빛 효과
  if (parrySuccessFlash > 0) {

    pushMatrix();
    translate(px, py, pz);

    noFill();

    stroke(
      0, 255, 255,
      map(parrySuccessFlash, 0, 25, 0, 180)
    );

    strokeWeight(3);

    sphere(
      40 + (25 - parrySuccessFlash) * 2
    );

    noStroke();
    popMatrix();
  }

  // 피격 무적시간 깜빡임
  if (invincible > 0 && tick % 8 < 4) {
    return;
  }

  pushMatrix();
  translate(px, py, pz);

  float bank = 0;

  if (leftKey) bank = -0.18;
  if (rightKey) bank = 0.18;

  rotateZ(bank);

  noStroke();

  // 몸체
  fill(180, 210, 245);
  box(24, 12, 65);

  // 기수
  fill(220, 235, 255);

  beginShape(TRIANGLES);

  vertex(0, 0, -60);
  vertex(-14, -4, -15);
  vertex(14, -4, -15);

  endShape();

  // 왼쪽 날개
  fill(45, 135, 245);

  beginShape(QUADS);

  vertex(-10, 0, -20);
  vertex(-67, 2, 27);
  vertex(-61, 2, 40);
  vertex(-10, 0, 20);

  endShape();

  // 오른쪽 날개
  beginShape(QUADS);

  vertex(10, 0, -20);
  vertex(67, 2, 27);
  vertex(61, 2, 40);
  vertex(10, 0, 20);

  endShape();

  // 조종석
  pushMatrix();

  translate(0, -9, -7);
  scale(0.75, 0.45, 1.7);

  fill(0, 220, 255);
  sphere(12);

  popMatrix();

  // 엔진
  for (int side = -1; side <= 1; side += 2) {

    pushMatrix();

    translate(side * 12, 1, 36);

    fill(90, 110, 150);
    box(13, 13, 19);

    translate(0, 0, 15);

    fill(0, 185, 255);
    sphere(7);

    pushMatrix();

    translate(0, 0, 10);

    scale(
      0.7,
      0.7,
      2.5 + random(0.4)
    );

    fill(70, 245, 255, 170);
    sphere(7);

    popMatrix();
    popMatrix();
  }

  // 날개 표시등
  fill(255, 65, 85);

  pushMatrix();

  translate(-57, -3, 29);
  sphere(5);

  popMatrix();

  pushMatrix();

  translate(57, -3, 29);
  sphere(5);

  popMatrix();

  popMatrix();
}

// =====================================
// ENEMY CLASS
// =====================================

class Enemy {

  float x, y, z;
  float tx, ty;
  float phase;
  float orbitAngle;
  float arriveRate;

  int type;
  int points;
  int combatAge = 0;

  boolean arriving = true;

  Enemy(float x, float y, float z, int type) {

    this.x = x;
    this.y = y;
    this.z = z;
    this.type = type;

    points = 40 - type * 10;

    phase = random(TWO_PI);
    arriveRate = random(0.07, 0.11);
  }

  void setTarget(float tx, float ty) {
    this.tx = tx;
    this.ty = ty;
  }

  void update() {

    // 먼 곳에서 빠르게 진입
    if (arriving) {

      x = lerp(x, tx, arriveRate);
      y = lerp(y, ty, arriveRate);
      z = lerp(z, ENEMY_Z, arriveRate);

      if (abs(x - tx) < 3 &&
          abs(y - ty) < 3 &&
          abs(z - ENEMY_Z) < 8) {

        arriving = false;

        x = tx;
        y = ty;
        z = ENEMY_Z;
      }

      return;
    }

    combatAge++;

    // 전투 Z축 고정
    z = ENEMY_Z;

    if (currentPattern == GRID) {

      tx += enemyDir * enemySpeed;
      x = tx;

      y = ty + sin(
        combatAge * 0.035 + phase
      ) * 6;

    } else if (currentPattern == V_FORM) {

      tx += enemyDir * enemySpeed;
      x = tx;

      y = ty + sin(
        combatAge * 0.04 + phase
      ) * 8;

    } else if (currentPattern == WAVE) {

      tx += enemyDir * enemySpeed * 0.8;
      x = tx;

      y = ty + sin(
        combatAge * 0.045 + phase
      ) * 15;

    } else if (currentPattern == RING) {

      float a =
        orbitAngle + combatAge * 0.008;

      x = cos(a) * 205;
      y = sin(a) * 86;
    }

    // 적이 공격 가능 범위 밖으로
    // 내려가지 않도록 제한
    x = constrain(x, -260, 260);

    y = constrain(
      y,
      MIN_ENEMY_Y,
      MAX_ENEMY_Y
    );
  }

  void display() {

    pushMatrix();
    translate(x, y, z);

    float tilt = sin(
      tick * 0.025 + phase
    );

    rotateZ(
      tilt * (arriving ? 0.28 : 0.07)
    );

    noStroke();

    if (type == 0) {
      fill(255, 65, 100);
    } else if (type == 1) {
      fill(255, 150, 45);
    } else {
      fill(65, 235, 135);
    }

    // 적 몸체
    pushMatrix();

    scale(1.15, 0.5, 1.3);
    sphere(17);

    popMatrix();

    // 날개
    pushMatrix();

    translate(0, 2, 0);
    box(65, 7, 16);

    popMatrix();

    for (int side = -1; side <= 1; side += 2) {

      pushMatrix();

      translate(side * 30, 0, 7);

      fill(100, 100, 155);
      box(14, 13, 22);

      fill(255, 55, 55);

      translate(0, -8, 0);
      sphere(5);

      popMatrix();
    }

    // 전면 발광부
    fill(255, 240, 80);

    pushMatrix();

    translate(-8, -7, 14);
    sphere(4);

    popMatrix();

    pushMatrix();

    translate(8, -7, 14);
    sphere(4);

    popMatrix();

    // 등장 시 엔진 불꽃
    if (arriving) {

      pushMatrix();

      translate(0, 0, 30);
      scale(0.8, 0.8, 2.7);

      fill(255, 120, 35, 170);
      sphere(8);

      popMatrix();
    }

    popMatrix();
  }
}

// =====================================
// ENEMY UPDATE
// =====================================

void updateEnemies() {

  if (enemies.size() == 0) {
    return;
  }

  // 아래로 내려가지 않고
  // 좌우 끝에서 방향만 바꿈
  if (currentPattern != RING) {

    for (Enemy e : enemies) {

      if (e.arriving) continue;

      if (e.tx + enemyDir * enemySpeed > 250 ||
          e.tx + enemyDir * enemySpeed < -250) {

        enemyDir *= -1;
        break;
      }
    }
  }

  for (Enemy e : enemies) {
    e.update();
  }

  if (state != 1) return;

  // 적 발사 타이머
  enemyFireTimer--;

  if (enemyFireTimer > 0) {
    return;
  }

  ArrayList<Enemy> ready =
    new ArrayList<Enemy>();

  for (Enemy e : enemies) {
    if (!e.arriving) {
      ready.add(e);
    }
  }

  if (ready.size() > 0) {

    Enemy e = ready.get(
      int(random(ready.size()))
    );

    // 플레이어를 향해 발사
    PVector direction = new PVector(
      px - e.x,
      py - e.y,
      pz - e.z
    );

    direction.normalize();

    // 탄환 비행 속도는 유지
    // 연사 빈도만 최대 3배
    direction.mult(9);

    shots.add(new Shot(
      e.x,
      e.y,
      e.z + 20,
      direction,
      false
    ));
  }

  scheduleEnemyShot();
}

void drawEnemies() {

  for (Enemy e : enemies) {
    e.display();
  }
}

// =====================================
// SHOT CLASS
// =====================================

class Shot {

  PVector pos;
  PVector vel;
  boolean friendly;

  Shot(
    float x,
    float y,
    float z,
    PVector vel,
    boolean friendly
  ) {

    pos = new PVector(x, y, z);

    this.vel = vel.copy();
    this.friendly = friendly;
  }

  void update() {
    pos.add(vel);
  }

  void display() {

    pushMatrix();
    translate(pos.x, pos.y, pos.z);

    PVector dir = vel.copy().normalize();

    PVector axis =
      new PVector(0, 0, 1);

    PVector cross = axis.cross(dir);

    float angle = acos(
      constrain(axis.dot(dir), -1, 1)
    );

    if (cross.mag() > 0.001) {

      rotate(
        angle,
        cross.x,
        cross.y,
        cross.z
      );
    }

    noStroke();

    if (friendly) {

      fill(0, 255, 255);
      box(5, 5, 40);

      fill(0, 255, 255, 90);
      sphere(8);

    } else {

      fill(255, 50, 75);
      box(6, 6, 30);
    }

    popMatrix();
  }
}

// =====================================
// COLLISION DETECTION
// =====================================

// 총알이 빠르게 움직여도
// 이전 위치와 현재 위치 사이에서
// 충돌 판정

boolean segmentHitsBox(
  PVector a,
  PVector b,
  float cx,
  float cy,
  float cz,
  float rx,
  float ry,
  float rz
) {

  float[] origin = {
    a.x, a.y, a.z
  };

  float[] delta = {
    b.x - a.x,
    b.y - a.y,
    b.z - a.z
  };

  float[] center = {
    cx, cy, cz
  };

  float[] radius = {
    rx, ry, rz
  };

  float tMin = 0;
  float tMax = 1;

  for (int axis = 0; axis < 3; axis++) {

    float low =
      center[axis] - radius[axis];

    float high =
      center[axis] + radius[axis];

    if (abs(delta[axis]) < 0.0001) {

      if (origin[axis] < low ||
          origin[axis] > high) {

        return false;
      }

    } else {

      float t1 =
        (low - origin[axis]) / delta[axis];

      float t2 =
        (high - origin[axis]) / delta[axis];

      if (t1 > t2) {

        float temp = t1;
        t1 = t2;
        t2 = temp;
      }

      tMin = max(tMin, t1);
      tMax = min(tMax, t2);

      if (tMin > tMax) {
        return false;
      }
    }
  }

  return true;
}

// =====================================
// SHOT COLLISION
// =====================================

void updateShots() {

  for (int i = shots.size()-1; i >= 0; i--) {

    Shot b = shots.get(i);

    PVector prev = b.pos.copy();
    b.update();

    if (b.pos.z < -3000 ||
        b.pos.z > 700 ||
        abs(b.pos.x) > 1200 ||
        abs(b.pos.y) > 900) {

      shots.remove(i);
      continue;
    }

    boolean hit = false;

    // 플레이어 총알 -> 적
    if (b.friendly) {

      for (int j = enemies.size()-1; j >= 0; j--) {

        Enemy e = enemies.get(j);

        if (segmentHitsBox(
          prev,
          b.pos,
          e.x, e.y, e.z,
          32, 25, 30
        )) {

          score += e.points;

          explode(
            e.x, e.y, e.z,
            color(255, 135, 45)
          );

          enemies.remove(j);

          hit = true;
          break;
        }
      }

    } else {

      // 적 총알 -> 플레이어
      if (segmentHitsBox(
        prev,
        b.pos,
        px, py, pz,
        24, 20, 35
      )) {

        if (invincible > 0) {

          // 피격 무적 시간
          hit = true;

        } else if (parryFrames > 0) {

          // =================================
          // PERFECT PARRY SUCCESS
          // =================================

          perfectParry();

          // 성공 시 쿨타임 없음
          hit = true;

        } else {

          // =================================
          // NORMAL DAMAGE
          // =================================

          lives--;

          invincible = 100;

          explode(
            px, py, pz,
            color(255, 80, 75)
          );

          hit = true;

          if (lives <= 0) {
            state = 2;
          }
        }
      }
    }

    if (hit) {
      shots.remove(i);
    }
  }
}

void drawShots() {

  for (Shot b : shots) {
    b.display();
  }
}

// =====================================
// EXPLOSION
// =====================================

class Spark {

  PVector pos, vel;

  int life = 32;
  float radius;
  color c;

  Spark(
    float x,
    float y,
    float z,
    color c
  ) {

    pos = new PVector(x, y, z);

    vel = new PVector(
      random(-6, 6),
      random(-6, 6),
      random(-6, 6)
    );

    radius = random(2, 6);
    this.c = c;
  }

  void update() {

    pos.add(vel);
    vel.mult(0.97);
    life--;
  }

  void display() {

    pushMatrix();
    translate(pos.x, pos.y, pos.z);

    noStroke();

    fill(
      c,
      map(life, 0, 32, 0, 255)
    );

    sphere(
      radius * max(0.1, life / 32.0)
    );

    popMatrix();
  }
}

void explode(
  float x,
  float y,
  float z,
  color c
) {

  for (int i = 0; i < 30; i++) {

    sparks.add(
      new Spark(x, y, z, c)
    );
  }
}

void updateSparks() {

  for (int i = sparks.size()-1; i >= 0; i--) {

    Spark s = sparks.get(i);
    s.update();

    if (s.life <= 0) {
      sparks.remove(i);
    }
  }
}

void drawSparks() {

  for (Spark s : sparks) {
    s.display();
  }
}

// =====================================
// STARFIELD
// =====================================

class Star {

  float x, y, z;
  float speed;
  float starSize;

  Star() {
    reset();
    z = random(-2500, 500);
  }

  void reset() {

    x = random(-1300, 1300);
    y = random(-800, 500);
    z = -2500;

    speed = random(4, 12);
    starSize = random(1, 3);
  }

  void update() {

    z += speed;

    if (z > 520) {
      reset();
    }
  }

  void display() {

    stroke(185, 215, 255);
    strokeWeight(starSize);

    point(x, y, z);
  }
}

void drawStars() {

  for (Star s : stars) {
    s.display();
  }

  noStroke();
}

// =====================================
// SPACE GRID
// =====================================

void drawGrid() {

  stroke(15, 55, 100, 80);
  strokeWeight(1);

  for (int x = -700; x <= 700; x += 100) {

    line(
      x, 185, -1700,
      x, 185, 480
    );
  }

  float offset = (tick * 3) % 100;

  for (int z = -1700; z <= 500; z += 100) {

    line(
      -700, 185, z + offset,
      700, 185, z + offset
    );
  }

  noStroke();
}

// =====================================
// 2D OVERLAY
// =====================================

void drawOverlay() {

  hint(DISABLE_DEPTH_TEST);

  camera();
  noLights();

  if (state == 0) {

    drawTitle();

  } else if (state == 2) {

    drawGameOver();

  } else {

    drawHUD();
    drawReticle();

    if (state == 3) {

      fill(0, 190);
      rect(0, 0, width, height);

      textAlign(CENTER, CENTER);

      fill(255);
      textSize(45);

      text(
        "PAUSED",
        width/2, height/2
      );

      textSize(19);

      text(
        "PRESS P TO RESUME",
        width/2, height/2 + 50
      );
    }
  }

  hint(ENABLE_DEPTH_TEST);
}

String patternName() {

  if (currentPattern == GRID) {
    return "GRID";
  }

  if (currentPattern == V_FORM) {
    return "V-FORM";
  }

  if (currentPattern == WAVE) {
    return "WAVE";
  }

  return "RING";
}

// =====================================
// AIM RETICLE
// =====================================

void drawReticle() {

  noFill();

  stroke(0, 240, 255);
  strokeWeight(2);

  ellipse(
    aimSX, aimSY,
    27, 27
  );

  line(
    aimSX - 23, aimSY,
    aimSX - 9, aimSY
  );

  line(
    aimSX + 9, aimSY,
    aimSX + 23, aimSY
  );

  line(
    aimSX, aimSY - 23,
    aimSX, aimSY - 9
  );

  line(
    aimSX, aimSY + 9,
    aimSX, aimSY + 23
  );

  strokeWeight(3);
  point(aimSX, aimSY);

  noStroke();
}

// =====================================
// GAME HUD
// =====================================

void drawHUD() {

  fill(0, 0, 20, 175);
  noStroke();

  rect(0, 0, width, 70);

  textSize(21);
  fill(0, 240, 255);

  textAlign(LEFT);

  text(
    "SCORE " + score,
    20, 39
  );

  textAlign(CENTER);

  text(
    "WAVE " + wave +
    " [" + patternName() + "]",
    width/2, 39
  );

  textAlign(RIGHT);

  fill(255, 100, 130);

  text(
    "LIVES " + lives,
    width - 20, 39
  );

  // 적 연사 속도 표시
  textAlign(CENTER);
  textSize(17);

  fill(255, 220, 90);

  text(
    "ENEMY FIRE x" +
    nf(enemyFireRate(), 1, 1),
    width/2, 94
  );

  // =====================================
  // PARRY STATUS
  // =====================================

  textAlign(CENTER);
  textSize(17);

  if (parryFrames > 0) {

    fill(0, 255, 255);

    text(
      "PARRY ACTIVE!",
      width/2, height - 90
    );

  } else if (parryCooldown > 0) {

    fill(255, 145, 100);

    text(
      "PARRY COOLDOWN " +
      nf(parryCooldown / 60.0, 1, 2) + "s",
      width/2, height - 90
    );

  } else {

    fill(80, 255, 170);

    text(
      "PARRY READY [SHIFT]",
      width/2, height - 90
    );
  }

  // 패링 게이지
  noStroke();

  fill(50, 60, 85);

  rect(
    width/2 - 80,
    height - 75,
    160, 6
  );

  float readyRatio =
    1 - float(parryCooldown) /
    PARRY_FAIL_COOLDOWN;

  readyRatio = constrain(
    readyRatio, 0, 1
  );

  fill(0, 235, 245);

  rect(
    width/2 - 80,
    height - 75,
    160 * readyRatio,
    6
  );

  // =====================================
  // PARRY SUCCESS MESSAGE
  // =====================================

  if (parrySuccessFlash > 0) {

    textAlign(CENTER);
    textSize(34);

    fill(0, 255, 255);

    text(
      "PERFECT PARRY! +50",
      width/2,
      height/2 - 70
    );
  }

  // =====================================
  // PARRY FAILED MESSAGE
  // =====================================

  if (parryFailFlash > 0) {

    textAlign(CENTER);
    textSize(27);

    fill(255, 100, 85);

    text(
      "PARRY FAILED!",
      width/2,
      height/2 - 70
    );
  }

  // 조작 안내
  textAlign(CENTER);
  textSize(14);

  fill(180, 200, 230);

  text(
    "WASD / ARROWS : MOVE    SPACE : FIRE    SHIFT : PARRY    P : PAUSE",
    width/2, height - 24
  );

  // 웨이브 클리어
  if (waveWait > 0 && enemies.size() == 0) {

    textSize(40);
    fill(255, 225, 70);

    text(
      "WAVE CLEAR!",
      width/2, 270
    );

    textSize(20);
    fill(255);

    text(
      "BONUS +250",
      width/2, 310
    );
  }
}

// =====================================
// TITLE SCREEN
// =====================================

void drawTitle() {

  fill(0, 0, 18, 185);
  rect(0, 0, width, height);

  textAlign(CENTER, CENTER);

  fill(0, 235, 255);
  textSize(56);

  text(
    "3D SPACE",
    width/2, 170
  );

  fill(255, 75, 110);
  textSize(68);

  text(
    "SHOOTER",
    width/2, 242
  );

  fill(255);
  textSize(20);

  text(
    "PERFECT PARRY EDITION",
    width/2, 320
  );

  fill(255, 225, 70);
  textSize(27);

  text(
    "PRESS ENTER TO START",
    width/2, 410
  );

  fill(200, 220, 245);
  textSize(18);

  text(
    "WASD / ARROWS : MOVE",
    width/2, 472
  );

  text(
    "SPACE : FIRE",
    width/2, 505
  );

  text(
    "SHIFT : PARRY (0.12s)",
    width/2, 538
  );

  text(
    "FAILED PARRY COOLDOWN : 1.3s",
    width/2, 571
  );

  text(
    "P : PAUSE     R : RESTART",
    width/2, 604
  );
}

// =====================================
// GAME OVER
// =====================================

void drawGameOver() {

  fill(0, 0, 18, 190);
  rect(0, 0, width, height);

  textAlign(CENTER, CENTER);

  fill(255, 65, 90);
  textSize(65);

  text(
    "GAME OVER",
    width/2, 255
  );

  fill(255);
  textSize(29);

  text(
    "FINAL SCORE : " + score,
    width/2, 355
  );

  text(
    "WAVE : " + wave,
    width/2, 410
  );

  fill(0, 240, 255);
  textSize(24);

  text(
    "PRESS R TO RESTART",
    width/2, 520
  );
}

// =====================================
// KEY PRESSED
// =====================================

void keyPressed() {

  if (key == CODED) {

    // 이동
    if (keyCode == LEFT) {
      leftKey = true;
    }

    if (keyCode == RIGHT) {
      rightKey = true;
    }

    if (keyCode == UP) {
      upKey = true;
    }

    if (keyCode == DOWN) {
      downKey = true;
    }

    // =================================
    // SHIFT PARRY
    // =================================

    if (keyCode == SHIFT) {

      // SHIFT를 새로 눌렀을 때만 발동
      if (!parryHeld) {

        startParry();
      }

      parryHeld = true;
    }

  } else {

    if (key == 'a' || key == 'A') {
      leftKey = true;
    }

    if (key == 'd' || key == 'D') {
      rightKey = true;
    }

    if (key == 'w' || key == 'W') {
      upKey = true;
    }

    if (key == 's' || key == 'S') {
      downKey = true;
    }

    if (key == ' ') {
      fireKey = true;
    }

    // 게임 시작
    if ((key == ENTER || key == RETURN) &&
        state == 0) {

      resetGame();
      state = 1;
    }

    // 재시작
    if (key == 'r' || key == 'R') {

      resetGame();
      state = 1;
    }

    // 일시정지
    if (key == 'p' || key == 'P') {

      if (state == 1) {
        state = 3;

      } else if (state == 3) {
        state = 1;
      }
    }
  }
}

// =====================================
// KEY RELEASED
// =====================================

void keyReleased() {

  if (key == CODED) {

    if (keyCode == LEFT) {
      leftKey = false;
    }

    if (keyCode == RIGHT) {
      rightKey = false;
    }

    if (keyCode == UP) {
      upKey = false;
    }

    if (keyCode == DOWN) {
      downKey = false;
    }

    // SHIFT를 떼면 다시 누를 수 있음
    if (keyCode == SHIFT) {
      parryHeld = false;
    }

  } else {

    if (key == 'a' || key == 'A') {
      leftKey = false;
    }

    if (key == 'd' || key == 'D') {
      rightKey = false;
    }

    if (key == 'w' || key == 'W') {
      upKey = false;
    }

    if (key == 's' || key == 'S') {
      downKey = false;
    }

    if (key == ' ') {
      fireKey = false;
    }
  }
}
