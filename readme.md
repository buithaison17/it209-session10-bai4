# Bài 4: Thiết lập Custom Network & Named Volume bằng Docker CLI

## 1. Mục tiêu

- Tạo Custom Bridge Network để các container giao tiếp nội bộ thông qua DNS của Docker.
- Tạo Named Volume để lưu trữ dữ liệu PostgreSQL bền vững.
- Khởi chạy PostgreSQL container và container kiểm tra kết nối mạng.
- Kiểm tra khả năng phân giải DNS bằng hostname `db-server`.
- Kiểm chứng dữ liệu không bị mất khi xóa và tạo lại container Database.

## 2. Mô hình triển khai

Hệ thống gồm các thành phần:

| Thành phần | Tên | Mô tả |
|---|---|---|
| Docker Network | `app-net` | Mạng Bridge kết nối các container |
| Docker Volume | `db-data` | Lưu trữ dữ liệu PostgreSQL |
| Database Container | `db-server` | Chạy PostgreSQL 15 |
| Backend Test Container | `app-container` | Kiểm tra kết nối mạng và DNS |
| Database | `appdb` | Cơ sở dữ liệu thử nghiệm |

### Sơ đồ kiến trúc

```text
              Docker Bridge Network
                    app-net
                       |
             +---------+---------+
             |                   |
      app-container          db-server
       Alpine Linux         PostgreSQL 15
             |                   |
             |  DB_HOST=         |
             |  db-server        |
             +------ DNS --------+
                                 |
                           Named Volume
                              db-data
                                 |
                                 v
                    /var/lib/postgresql/data
```

## 3. Công nghệ sử dụng

- Docker CLI
- Docker Bridge Network
- Docker Named Volume
- PostgreSQL 15 Alpine
- Alpine Linux
- Bash Shell

## 4. Các bước thực hiện

Toàn bộ quy trình được tự động hóa bằng file `commands.sh`.

### Bước 1: Tạo Docker Network

Tạo mạng Bridge có tên `app-net` để các container có thể giao tiếp với nhau.

```bash
docker network create app-net
```

### Bước 2: Tạo Named Volume

Tạo volume `db-data` để lưu trữ dữ liệu PostgreSQL độc lập với vòng đời của container.

```bash
docker volume create db-data
```

### Bước 3: Khởi chạy PostgreSQL

Khởi chạy container `db-server` sử dụng image `postgres:15-alpine` và mount volume `db-data` vào thư mục dữ liệu của PostgreSQL.

```bash
docker run -d \
  --name db-server \
  --network app-net \
  -e POSTGRES_DB=appdb \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=apppassword \
  -v db-data:/var/lib/postgresql/data \
  postgres:15-alpine
```

### Bước 4: Khởi chạy container kiểm tra mạng

Container `app-container` tham gia mạng `app-net` và sử dụng hostname `db-server` làm địa chỉ kết nối Database.

Biến môi trường kết nối:

- `DB_HOST=db-server`
- `DB_PORT=5432`

Docker cung cấp DNS nội bộ cho các container cùng mạng Bridge do người dùng tạo.

### Bước 5: Kiểm tra DNS

```bash
docker exec app-container ping -c 2 db-server
```

Nếu thành công, hostname `db-server` sẽ được phân giải thành địa chỉ IP nội bộ của container Database.

### Bước 6: Kiểm tra Data Persistence

Script tự động thực hiện các thao tác:

1. Tạo bảng `persistence_test`.
2. Thêm bản ghi kiểm thử có nội dung `Data persists!`.
3. Xóa container Database bằng `docker rm -f db-server`.
4. Tạo lại container `db-server` với cùng volume `db-data`.
5. Truy vấn lại dữ liệu để xác minh tính toàn vẹn.

Lệnh kiểm tra dữ liệu:

```bash
docker exec db-server \
  psql -U appuser -d appdb \
  -c "SELECT * FROM persistence_test;"
```

## 5. Cách chạy chương trình

Yêu cầu VPS đã cài đặt Docker Engine và có quyền thực thi các lệnh Docker.

Di chuyển đến thư mục bài tập:

```bash
cd ~/homework/session_10/ex4
```

Cấp quyền thực thi:

```bash
chmod +x commands.sh
```

Chạy script:

```bash
./commands.sh
```

Script sẽ tự động tạo network, volume, khởi chạy các container, kiểm tra DNS và xác minh dữ liệu PostgreSQL sau khi container Database được tạo lại.

## 6. Các lệnh kiểm tra

### Kiểm tra Network

```bash
docker network ls | grep app-net
docker network inspect app-net
```

### Kiểm tra Volume

```bash
docker volume ls | grep db-data
docker volume inspect db-data
```

### Kiểm tra các container

```bash
docker ps -a
```

### Kiểm tra kết nối DNS

```bash
docker exec app-container ping -c 2 db-server
```

### Kiểm tra dữ liệu PostgreSQL

```bash
docker exec db-server \
  psql -U appuser -d appdb \
  -c "SELECT * FROM persistence_test;"
```

## 7. Kết quả mong đợi

- Network `app-net` được tạo thành công.
- Volume `db-data` được tạo thành công.
- Container `db-server` chạy PostgreSQL 15.
- Container `app-container` phân giải thành công hostname `db-server`.
- Bản ghi kiểm thử vẫn tồn tại sau khi container Database bị xóa và tạo lại.
- Script kết thúc với thông báo thành công.

## 8. Kết luận

Bài thực hành giúp hiểu cách sử dụng Docker CLI để quản lý mạng nội bộ và lưu trữ dữ liệu bền vững.

Custom Bridge Network cho phép các container giao tiếp bằng hostname thông qua DNS nội bộ của Docker. Named Volume giúp dữ liệu PostgreSQL tồn tại độc lập với vòng đời container.

Việc xóa và tạo lại container Database nhưng vẫn truy vấn được dữ liệu cũ chứng minh rằng dữ liệu đã được lưu trữ trên Named Volume `db-data`.

**Lưu ý:** `app-container` trong bài này là container kiểm thử mạng, không phải Web API thực tế. Mật khẩu Database được sử dụng chỉ nhằm mục đích thực hành, không nên dùng trực tiếp trong môi trường production.