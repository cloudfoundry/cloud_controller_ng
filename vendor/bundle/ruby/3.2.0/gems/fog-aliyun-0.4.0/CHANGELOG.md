## 0.4.1 (Unreleased)
## 0.4.0 (August 17, 2022)

IMPROVEMENTS:
- Ruby 3 [GH-158](https://github.com/fog/fog-aliyun/pull/158)

## 0.3.19 (August 17, 2020)

IMPROVEMENTS:

- Upgrade oss ruby sdk to support setting log level [GH-152](https://github.com/fog/fog-aliyun/pull/152)

## 0.3.18 (August 03, 2020)

IMPROVEMENTS:

- reconstruct perform test [GH-148](https://github.com/fog/fog-aliyun/pull/148)
- Reconstruct fog-aliyun by using oss [GH-147](https://github.com/fog/fog-aliyun/pull/147)
- reconstruct cover case test [GH-146](https://github.com/fog/fog-aliyun/pull/146)
- reconstruct case test [GH-144](https://github.com/fog/fog-aliyun/pull/144)
- reconstruct parts two of file [GH-143](https://github.com/fog/fog-aliyun/pull/143)
- implement blobstore for cloud_controller_ng [GH-142](https://github.com/fog/fog-aliyun/pull/142)
- reconstruct parts of file [GH-141](https://github.com/fog/fog-aliyun/pull/141)
- reconstruct the files [GH-140](https://github.com/fog/fog-aliyun/pull/140)
- reconstruct the directory [GH-139](https://github.com/fog/fog-aliyun/pull/139)
- reconstruct the directories [GH-138](https://github.com/fog/fog-aliyun/pull/138)
- improve files.get code [GH-137](https://github.com/fog/fog-aliyun/pull/137)
- add testcase for testing head notexistfile [GH-136](https://github.com/fog/fog-aliyun/pull/136)
- improve head_object using oss sdk [GH-135](https://github.com/fog/fog-aliyun/pull/135)

BUG FIXES:

- fix files all options problem [GH-149](https://github.com/fog/fog-aliyun/pull/149)

## 0.3.17 (July 06, 2020)

IMPROVEMENTS:
- adater oss_sdk_log_path [GH-125](https://github.com/fog/fog-aliyun/pull/125)
- update ruby sdk to 0.7.3 [GH-124](https://github.com/fog/fog-aliyun/pull/124)
- adapter maxkeys conversion problem [GH-123](https://github.com/fog/fog-aliyun/pull/123)
- [Enhance tests][Auth & Connectivity scenarios] Test that API cannot be accessed using incorrect credentials [GH-117](https://github.com/fog/fog-aliyun/pull/117)
- [Enhance tests][Auth & Connectivity scenarios] Test that API can be accessed using valid credentials [GH-116](https://github.com/fog/fog-aliyun/pull/116)
- adapter custom log environment variable [GH-114](https://github.com/fog/fog-aliyun/pull/114)
- [Enhance tests][Buckets scenarios] (NEGATIVE TEST) Test that error is thrown when trying to access non-existing bucket [GH-110](https://github.com/fog/fog-aliyun/pull/110)
- [Enhance tests][Buckets scenarios] (NEGATIVE TEST) Test that error is thrown when trying to create already existing bucket [GH-109](https://github.com/fog/fog-aliyun/pull/109)
- [Enhance tests][Buckets scenarios] Test that it is possible to destroy a bucket [GH-108](https://github.com/fog/fog-aliyun/pull/108)
- [Enhance tests][Buckets scenarios] Test that it is possible to create a new bucket [GH-107](https://github.com/fog/fog-aliyun/pull/107)
- [Enhance tests][Buckets scenarios] Test that it is possible to list all buckets [GH-105](https://github.com/fog/fog-aliyun/pull/105)
- [Enhance tests][Files & Directory scenarios] Test getting bucket when directory exists named with the same name as a bucket [GH-101](https://github.com/fog/fog-aliyun/pull/101)
- [Enhance tests][Files & Directory scenarios] Test file copy operations [GH-100](https://github.com/fog/fog-aliyun/pull/100)
- reset the last PR [GH-133](https://github.com/fog/fog-aliyun/pull/133)
- improve put_object_with_body and head_object using sdk do_request [GH-131](https://github.com/fog/fog-aliyun/pull/131)

BUG FIXES:
- fix max key again [GH-128](https://github.com/fog/fog-aliyun/pull/128)
- fix downloading object when pushing app twice [GH-127](https://github.com/fog/fog-aliyun/pull/127)
- fix max key [GH-126](https://github.com/fog/fog-aliyun/pull/126)
- fix max-keys conversion problem [GH-121](https://github.com/fog/fog-aliyun/pull/121)
- fix @aliyun_oss_sdk_log_path is nil  [GH-132](https://github.com/fog/fog-aliyun/pull/132)

## 0.3.16 (June 18, 2020)

IMPROVEMENTS:
- [Enhance tests][Files & Directory scenarios] Test get nested directories and files in nested directory [GH-98](https://github.com/fog/fog-aliyun/pull/98)
- remove get_bucket_location and use ruby sdk to improve performance when uploading object [GH-97](https://github.com/fog/fog-aliyun/pull/97)
- using bucket_exist to checking bucket [GH-95](https://github.com/fog/fog-aliyun/pull/95)
- add change log [GH-94](https://github.com/fog/fog-aliyun/pull/94)

BUG FIXES:
- fix delete all of files bug when specifying a prefix [GH-102](https://github.com/fog/fog-aliyun/pull/102)

## 0.3.15 (June 05, 2020)

BUG FIXES:
- change dependence ruby sdk to gems [GH-92](https://github.com/fog/fog-aliyun/pull/92)

## 0.3.13 (June 02, 2020)

IMPROVEMENTS:
- using ruby sdk to delete object [GH-90](https://github.com/fog/fog-aliyun/pull/90)

## 0.3.12 (May 28, 2020 )

BUG FIXES:
- add missing dependence [GH-88](https://github.com/fog/fog-aliyun/pull/88)

## 0.3.11 (May 25, 2020)

IMPROVEMENTS:
- using oss ruby sdk to improve downloading object performance [GH-86](https://github.com/fog/fog-aliyun/pull/86)
- Add performance tests [GH-85](https://github.com/fog/fog-aliyun/pull/85)
- [Enhance tests][Entity operations]Add tests for each type of entity that validates the CURD operations [GH-84](https://github.com/fog/fog-aliyun/pull/84)
- [Enhance tests][Auth & Connectivity scenarios] Test region is selected according to provider configuration [GH-83](https://github.com/fog/fog-aliyun/pull/83)
- [Enhance tests][Files & Directory scenarios] test file listing using parameters such as prefix, marker, delimeter and maxKeys [GH-82](https://github.com/fog/fog-aliyun/pull/82)
- [Enhance tests][Files & Directory scenarios]test directory listing using parameters such as prefix, marker, delimeter and maxKeys [GH-81](https://github.com/fog/fog-aliyun/pull/81)
- [Enhance tests][Files & Directory scenarios]Test that it is possible to upload (write) large file (multi part upload) [GH-79](https://github.com/fog/fog-aliyun/pull/79)
- upgrade deprecated code [GH-78](https://github.com/fog/fog-aliyun/pull/78)
- improve fog/integration_spec [GH-77](https://github.com/fog/fog-aliyun/pull/77)
- [Enhance tests][Files & Directory scenarios]Test that it is possible to upload (write) a file [GH-76](https://github.com/fog/fog-aliyun/pull/76)
- upgrade deprecated code [GH-74](https://github.com/fog/fog-aliyun/pull/74)
- support https scheme [GH-71](https://github.com/fog/fog-aliyun/pull/71)
- [Enhance tests][Files & Directory scenarios]Test that it is possible to destroy a file/directory [GH-69](https://github.com/fog/fog-aliyun/pull/69)
- improve fog/integration_spec [GH-68](https://github.com/fog/fog-aliyun/pull/68)
- Implement basic integration tests [GH-66](https://github.com/fog/fog-aliyun/pull/66)

## 0.3.10 (May 07, 2020)

IMPROVEMENTS:
- Set max limitation to 1000 when get objects [GH-64](https://github.com/fog/fog-aliyun/pull/64)

## 0.3.9 (May 07, 2020)

BUG FIXES:
- diectories.get supports options to filter the specified objects [GH-62](https://github.com/fog/fog-aliyun/pull/62)
