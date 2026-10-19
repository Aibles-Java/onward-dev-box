# onward-dev-box — Roadmap v2 (Vault · Schema · Redis · Kafka)

> Ngày lập: 2026-10-19 · Trạng thái: **Draft** — cần chốt các mục ở §1 trước khi tạo issue.
> Nền tảng hiện tại: Phase 1–3 trong `INFRASTRUCTURE.md` đã xong (còn #18).

**Hai phần việc** (chia theo phụ thuộc kỹ thuật):

| Phần | Nội dung | Lý do đi chung |
|---|---|---|
| **Phần 1 — Dữ liệu & Bí mật** | Chia schema Postgres + Vault | Vault cấp tài khoản DB động theo từng role của schema |
| **Phần 2 — Cache & Messaging** | Redis + Kafka | Luồng điển hình: flag đổi → Kafka event → xoá cache Redis |

**Chú thích màu** dùng trong toàn bộ tài liệu:

| Màu | Ý nghĩa |
|---|---|
| 🟪 Tím | P0 — quyết định / chuẩn bị |
| 🟦 Xanh dương | Phần 1 — Dữ liệu & Bí mật |
| 🟩 Xanh lá | Phần 2 — Cache & Messaging |
| 🟧 Cam | Tích hợp chéo repo (`feature_flag`) |
| 🟥 Đỏ | Rủi ro / điểm hay sai |

---

## 1. Cần chốt trước khi bắt đầu

1. **Chưa có service nào cần các thành phần này.** `INFRASTRUCTURE.md` §1 ghi rõ feature_flag *không cần* Redis/Kafka. Phải chọn một use case cụ thể trước, nếu không sẽ thành dựng hạ tầng mà không ai dùng.
2. **"Chia schema" có 2 nghĩa:**
   - (a) Postgres: mỗi service một schema.
   - (b) Kafka Schema Registry.

   Roadmap này giả định là (a); (b) để thành mục tuỳ chọn (2.5).
3. **Xung đột port:** Schema Registry mặc định chạy port `8081`, trùng với feature_flag. Phải đăng ký port `8085`.

---

## 2. Bản đồ phân rã

```mermaid
flowchart LR
    ROOT(["DEVBOX v2"]):::root

    ROOT --> P0["P0. Quyết định & chuẩn bị<br/>1d"]:::p0
    P0 --> P0a["ADR-0002 chiến lược schema"]:::p0
    P0 --> P0b["ADR-0003 Vault dev / server mode"]:::p0
    P0 --> P0c["Đăng ký port §4"]:::p0
    P0 --> P0d["Profile: secrets · cache · messaging"]:::p0

    ROOT --> A["PHẦN 1 — Dữ liệu & Bí mật<br/>9–12d"]:::partA
    A --> A1["1.1 Chia schema Postgres<br/>1.5–2d"]:::partA
    A --> A2["1.2 Vault service trong compose<br/>0.5d"]:::partA
    A --> A3["1.3 vault/bootstrap.sh<br/>2–3d"]:::partA
    A --> A4["1.4 Make targets + doctor<br/>0.5d"]:::partA
    A --> A5["1.5 Tích hợp feature_flag<br/>2–3d"]:::xrepo
    A --> A6["1.6 Kiểm tra + RUNBOOK + CI<br/>1d"]:::partA
    A3 --> A3a["KV v2: JWT secret"]:::partA
    A3 --> A3b["AppRole + policy cho từng service"]:::partA
    A3 --> A3c["Database engine: tài khoản DB động"]:::partA
    A5 --> R1["⚠ spring-cloud-vault có hỗ trợ Boot 4.1 không?"]:::risk

    ROOT --> B["PHẦN 2 — Cache & Messaging<br/>10–13d"]:::partB
    B --> B1["2.1 Redis + ACL + RedisInsight<br/>0.5–1d"]:::partB
    B --> B2["2.2 Cache flag-evaluation<br/>2d"]:::xrepo
    B --> B3["2.3 Kafka KRaft 1 node<br/>1d"]:::partB
    B --> B4["2.4 Script topic + quy ước tên<br/>1d"]:::partB
    B --> B5["2.5 Kafka UI + Schema Registry tuỳ chọn<br/>0.5–1d"]:::partB
    B --> B6["2.6 Event flag-changed qua outbox<br/>2–3d"]:::xrepo
    B --> B7["2.7 Smoke + RAM doctor + docs + CI<br/>1–1.5d"]:::partB
    B3 --> R2["⚠ Listener nội bộ / bên ngoài"]:::risk

    classDef root  fill:#1f2937,stroke:#111827,color:#ffffff,font-weight:bold
    classDef p0    fill:#ede9fe,stroke:#7c3aed,color:#3b0764
    classDef partA fill:#dbeafe,stroke:#2563eb,color:#1e3a8a
    classDef partB fill:#dcfce7,stroke:#16a34a,color:#14532d
    classDef xrepo fill:#ffedd5,stroke:#ea580c,color:#7c2d12
    classDef risk  fill:#fee2e2,stroke:#dc2626,color:#7f1d1d
```

---

## 3. Phụ thuộc & critical path

Mũi tên **đỏ đậm** là critical path.

```mermaid
flowchart TD
    P0["P0 Quyết định"]:::p0
    S11["1.1 Chia schema"]:::partA
    S12["1.2 Vault compose"]:::partA
    S13["1.3 Vault bootstrap"]:::partA
    S14["1.4 Make + doctor"]:::partA
    S15["1.5 feature_flag ↔ Vault"]:::xrepo
    S16["1.6 Verify Phần 1"]:::partA

    S21["2.1 Redis"]:::partB
    S22["2.2 Cache flag-eval"]:::xrepo
    S23["2.3 Kafka KRaft"]:::partB
    S24["2.4 Topics"]:::partB
    S25["2.5 Kafka UI / Registry"]:::partB
    S26["2.6 Event flag-changed"]:::xrepo
    S27["2.7 Verify Phần 2"]:::partB

    P0 ==> S11 ==> S13 ==> S15 ==> S16
    P0 --> S12 --> S13
    S13 --> S14 --> S16

    P0 --> S21 --> S22 --> S26
    P0 --> S23 --> S24 --> S26
    S23 --> S25
    S26 --> S27
    S25 --> S27

    linkStyle 0,1,2,3 stroke:#dc2626,stroke-width:3px

    classDef p0    fill:#ede9fe,stroke:#7c3aed,color:#3b0764
    classDef partA fill:#dbeafe,stroke:#2563eb,color:#1e3a8a
    classDef partB fill:#dcfce7,stroke:#16a34a,color:#14532d
    classDef xrepo fill:#ffedd5,stroke:#ea580c,color:#7c2d12
```

---

## 4. Phân rã khái niệm Vault ("vauth" = Vault auth)

```mermaid
mindmap
  root((Vault))
    Vận hành
      Seal / Unseal
        Dev-mode tự unseal
        Chạy trên RAM, mất dữ liệu khi restart
      Storage backend
        in-memory · file · raft
    Auth — vauth
      token
      userpass — cho người
      AppRole — cho app
        role_id + secret_id
      kubernetes — SIT/PROD
    Phân quyền
      Policy HCL theo path
      Token gắn policy + TTL
    Secrets engine
      KV v2 — key-value có version
      Database — tài khoản DB động
      Transit — mã hoá giúp app
    Vòng đời
      Lease
      Renew / Revoke
    Giám sát
      Audit device
```

| Lớp | Khái niệm | Ý nghĩa ngắn gọn |
|---|---|---|
| Bản chất | **Vault** | Nơi giữ bí mật, xác thực ai được đọc bí mật nào, và có thể mã hoá dữ liệu thay cho app |
| Vận hành | **Seal / Unseal** | Vault khởi động ở trạng thái khoá và cần key mới mở được. Dev-mode tự mở và chạy trên RAM, nên bootstrap phải chạy lại được |
| | **Storage backend** | Nơi Vault lưu dữ liệu (đã mã hoá) |
| **Auth (vauth)** | **Auth method** | Cách client chứng minh mình là ai: `token`, `userpass`, `AppRole`, `kubernetes` |
| | **Token** | Kết quả sau khi login, có TTL và gắn với các policy |
| Phân quyền | **Policy** | ACL viết bằng HCL theo path, ví dụ `path "kv/data/feature_flag/*" { capabilities = ["read"] }` |
| Bí mật | **Secrets engine** | Plugin mount vào một path: **KV v2**, **Database**, **Transit** |
| Vòng đời | **Lease** | Mỗi bí mật động có TTL, có thể renew; hết hạn hoặc bị revoke thì bị thu hồi |
| Giám sát | **Audit device** | Ghi log mọi request |

### Luồng app lấy bí mật

```mermaid
sequenceDiagram
    autonumber
    participant APP as feature_flag
    participant V as Vault
    participant PG as Postgres

    rect rgb(237, 233, 254)
    Note over APP,V: Auth — vauth
    APP->>V: login AppRole (role_id + secret_id)
    V-->>APP: token (policy ff-read, TTL)
    end

    rect rgb(219, 234, 254)
    Note over APP,V: Bí mật tĩnh — KV v2
    APP->>V: read kv/feature_flag/jwt
    V-->>APP: JWT secret
    end

    rect rgb(220, 252, 231)
    Note over APP,PG: Bí mật động — Database engine
    APP->>V: read database/creds/ff-app
    V->>PG: CREATE ROLE tạm, GRANT ff_app
    V-->>APP: username/password + lease
    end

    rect rgb(254, 226, 226)
    Note over APP,PG: Vòng đời lease
    APP->>V: renew lease
    V->>PG: DROP ROLE khi hết hạn / bị revoke
    end
```

**Liên hệ với chia schema:** mỗi schema có các role `owner` / `app` / `readonly`. Mỗi role trong database engine của Vault tương ứng với một role Postgres, nên **1.1 phải xong trước 1.3**.

---

## 5. Phân rã khái niệm Redis & Kafka

```mermaid
mindmap
  root((Cache & Messaging))
    Redis
      Kiểu dữ liệu: string · hash · set · zset
      TTL & eviction
      Cache-aside
      ACL user cho từng service
      Persistence RDB / AOF — tắt khi local
    Kafka
      Broker
      Topic → Partition → Offset
      Producer / Consumer group
      KRaft — không cần Zookeeper
      Listener nội bộ / bên ngoài
      Outbox pattern
      Schema Registry — tuỳ chọn
```

### Luồng ghép Redis + Kafka (mục 2.6)

```mermaid
flowchart LR
    U["Admin cập nhật flag"]:::xrepo --> API["feature_flag API"]:::xrepo
    API --> DB[("Postgres<br/>flags + outbox")]:::partA
    DB --> RELAY["Outbox relay"]:::xrepo
    RELAY --> K[["Kafka topic<br/>feature_flag.flag.changed"]]:::partB
    K --> C["Consumer"]:::xrepo
    C --> R[("Redis<br/>xoá key cache")]:::partB
    SDK["SDK evaluate"]:::p0 --> R
    R -. miss .-> DB

    classDef p0    fill:#ede9fe,stroke:#7c3aed,color:#3b0764
    classDef partA fill:#dbeafe,stroke:#2563eb,color:#1e3a8a
    classDef partB fill:#dcfce7,stroke:#16a34a,color:#14532d
    classDef xrepo fill:#ffedd5,stroke:#ea580c,color:#7c2d12
```

---

## 6. Đăng ký port mới (bổ sung `INFRASTRUCTURE.md` §4)

| Port | Service | Profile | Ghi chú |
|---|---|---|---|
| 8200 | Vault | secrets | |
| 6379 | Redis | cache | |
| 5540 | RedisInsight | tools | |
| 9092 | Kafka (listener cho host) | messaging | Listener nội bộ dùng `kafka:29092` |
| 8085 | Schema Registry | messaging | 🟥 Mặc định là 8081, trùng feature_flag |
| 8088 | Kafka UI | messaging | |

---

## 7. Ước lượng thời gian

```mermaid
gantt
    title Roadmap devbox v2 (1 người, ngày làm việc)
    dateFormat YYYY-MM-DD
    excludes weekends

    section P0
    ADR + port + profile          :crit, p0, 2026-10-20, 1d

    section Học khái niệm
    Vault                         :active, l1, after p0, 2d

    section Phần 1 — Dữ liệu & Bí mật
    1.1 Chia schema               :crit, a1, after l1, 2d
    1.2 Vault compose             :a2, after a1, 1d
    1.3 Vault bootstrap           :crit, a3, after a2, 3d
    1.4 Make + doctor             :a4, after a3, 1d
    1.5 feature_flag ↔ Vault      :crit, a5, after a4, 3d
    1.6 Verify Phần 1             :milestone, a6, after a5, 1d

    section Phần 2 — Cache & Messaging
    Học Kafka + Redis             :active, l2, after a6, 3d
    2.1 Redis                     :b1, after l2, 1d
    2.2 Cache flag-eval           :b2, after b1, 2d
    2.3 Kafka KRaft               :b3, after b2, 1d
    2.4 Topics                    :b4, after b3, 1d
    2.5 Kafka UI / Registry       :b5, after b4, 1d
    2.6 Event flag-changed        :crit, b6, after b5, 3d
    2.7 Verify Phần 2             :milestone, b7, after b6, 1d
```

> Gantt dùng màu theo trạng thái của Mermaid: **crit** (đỏ) = critical path, **active** (xanh) = học khái niệm, còn lại là màu mặc định.

| Hạng mục | Chỉ phía devbox | Tính cả tích hợp feature_flag |
|---|---|---|
| 🟪 P0 | 1d | 1d |
| 🟦 Phần 1 | ~5–6d | 9–12d |
| 🟩 Phần 2 | ~4–5d | 10–13d |
| Học khái niệm mới (Vault ~2d, Kafka ~2d, Redis ~0.5d) | +4.5d | +4.5d |
| **Tổng (1 người)** | **~2.5–3 tuần** | **~5–6 tuần** |

**Lưu ý về độ tin cậy:** bảng calibration của Phase 1–2 chưa ghi giờ thực tế (cột `Actual` vẫn trống), nên các con số này chưa được đối chiếu với tốc độ thực tế của team. Nên cộng thêm 20–30% buffer. Phần thuần devbox có thể nhanh hơn (Phase 1 cũ gồm 8 issue xong trong khoảng 2 ngày). Phần tích hợp chéo repo và phần học khái niệm mới thì khó rút ngắn.
