# Homework 3: Cấu hình Cảnh báo Đăng nhập Tài khoản Root (AWS Root Account Login Alert)

Tài liệu này hướng dẫn cách triển khai hệ thống tự động cảnh báo khi có hoạt động đăng nhập bằng tài khoản **Root** trên AWS bằng **Terraform** theo đúng yêu cầu trong bài học.

---

## 📋 Mục tiêu bài tập (Objectives)

Dựa trên slide hướng dẫn **"Hands-On: Alert on AWS Root Account Login"**, chúng ta thực hiện tự động hóa 4 bước sau bằng Terraform:
1. **Enable CloudTrail & Send Logs to CloudWatch**: Bật CloudTrail và cấu hình gửi logs về CloudWatch Logs Group.
2. **Create CloudWatch Metric Filter**: Tạo bộ lọc để phát hiện sự kiện đăng nhập Root với Filter Pattern:
   `{ $.userIdentity.type = "Root" && $.eventType != "AwsServiceEvent" }`
3. **Create CloudWatch Alarm**: Tạo cảnh báo nếu xuất hiện ít nhất 1 lần đăng nhập Root (`RootAccountLoginCount >= 1`) trong khoảng thời gian 5 phút.
4. **Notify via SNS**: Gửi cảnh báo ngay lập tức qua **Email** (và tùy chọn **SMS**) thông qua SNS Topic.

---

## 🛠️ Bản đồ Tài nguyên Terraform (Terraform Architecture Mapping)

| Slide Step | AWS Resource | Terraform Resource Name | Chức năng (Function) |
| :--- | :--- | :--- | :--- |
| **Bước 1** | CloudTrail | `aws_cloudtrail.root_login_trail` | Theo dõi hoạt động trên AWS Account |
| **Bước 1** | S3 Bucket | `aws_s3_bucket.cloudtrail_bucket` | Lưu trữ logs gốc của CloudTrail (bắt buộc) |
| **Bước 1** | Log Group | `aws_cloudwatch_log_group.cloudtrail_logs` | Điểm nhận logs từ CloudTrail để lọc |
| **Bước 1** | IAM Role/Policy | `aws_iam_role.cloudtrail_to_cloudwatch_role` | Cấp quyền cho CloudTrail ghi logs vào CloudWatch |
| **Bước 2** | Metric Filter | `aws_cloudwatch_log_metric_filter.root_login_filter` | Lọc logs đăng nhập Root và ghi nhận số lượng |
| **Bước 3** | CloudWatch Alarm | `aws_cloudwatch_metric_alarm.root_login_alarm` | Kích hoạt báo động khi số lần đăng nhập >= 1 |
| **Bước 4** | SNS Topic | `aws_sns_topic.root_login_topic` | Kênh phân phối thông báo |
| **Bước 4** | SNS Subscription | `aws_sns_topic_subscription.email_subscription` | Đăng ký nhận thông báo qua Email |
| **Bước 4** | SNS Subscription | `aws_sns_topic_subscription.sms_subscription` | (Tùy chọn) Đăng ký nhận thông báo qua SMS |

---

## 🚀 Hướng dẫn triển khai (Deployment Guide)

### Bước 1: Khởi tạo thư mục
Di chuyển vào thư mục `Homework3` trong terminal của bạn:
```powershell
cd "c:\Users\THANH TRUNG\Desktop\Xbrain\Homework3"
```

### Bước 2: Khởi tạo Terraform
Chạy lệnh sau để tải các providers cần thiết (AWS, Random):
```bash
terraform init
```

### Bước 3: Cấu hình thông tin cá nhân
Tạo file `terraform.tfvars` từ file mẫu:
```powershell
copy terraform.tfvars.example terraform.tfvars
```
Mở file `terraform.tfvars` mới tạo và điền các thông tin của bạn:
```hcl
# AWS Region mong muốn deploy
aws_region = "ap-southeast-1"

# Email nhận cảnh báo (Thay bằng email thực tế của bạn)
alert_email = "your-real-email@gmail.com"

# Điền số điện thoại nếu muốn nhận SMS (vd: "+84912345678"), bỏ trống nếu chỉ dùng Email
alert_phone_number = ""
```

### Bước 4: Deploy tài nguyên lên AWS
Chạy lệnh kiểm tra và tiến hành triển khai:
```bash
terraform apply -auto-approve
```

### Bước 5: Xác nhận Đăng ký Email (Confirm Subscription)
1. Kiểm tra hộp thư đến của email bạn đã nhập ở Bước 3.
2. Tìm thư từ **AWS Notifications** có tiêu đề `AWS Notification - Subscription Confirmation`.
3. Click vào link **Confirm Subscription** trong mail để đồng ý nhận cảnh báo.

---

## 🧪 Hướng dẫn kiểm tra hoạt động (Verification & Testing)

1. **Đăng xuất** tài khoản IAM hiện tại.
2. **Đăng nhập vào AWS Console bằng tài khoản Root** (Root user email + mật khẩu chính).
3. **Đợi từ 3 - 5 phút** để CloudTrail đẩy log về CloudWatch và Metric Filter bắt được sự kiện.
4. Kiểm tra trên CloudWatch Console:
   * **Metric:** Vào mục **All metrics** -> **Security** -> **RootAccountLoginCount** để xem biểu đồ giá trị tăng lên `1`.
   * **Alarm:** Trạng thái của `RootAccountLoginAlarm` sẽ chuyển từ `OK` sang `ALARM`.
5. Kiểm tra hộp thư Email hoặc điện thoại của bạn, bạn sẽ nhận được một thông báo cảnh báo chi tiết từ SNS.

---

## 🧹 Dọn dẹp tài nguyên (Cleanup)

Để tránh phát sinh chi phí không mong muốn trên tài khoản AWS của bạn sau khi hoàn thành bài tập, hãy xóa sạch các tài nguyên đã tạo bằng lệnh:
```bash
terraform destroy -auto-approve
```
*(Lưu ý: S3 Bucket lưu logs CloudTrail đã cấu hình `force_destroy = true` nên sẽ tự động xóa sạch các logs bên trong mà không gặp lỗi).*
