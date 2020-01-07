Aerospike AWS Examples
================================================================================

Temporary Notes
--------------------------------------------------------------------------------

Provision the example AWS resources using `terraform apply`:

```
terraform apply -var-file=examples/example-02.tfvars -var='key_name=micahcarrick'
```

Use the `-j` flag to SSH to the Aerospike nodes through the bastion host:

```
ssh -J ec2-user@[bastion host IP] ec2-user@[aerospike node IP]
```

Verify Aerospike Server instances are routed through the NAT Gateway:

```
sudo traceroute -T amazon.com
```

Security Model
--------------------------------------------------------------------------------



Examples
--------------------------------------------------------------------------------

### Example 01

This example demonstrates a simple 2-AZ cluster using `m5d.large` EC2 instances.

TODO

### Example 02

This example demonstrates a 2-AZ cluster using EBS Volumes as 
[Shadow Devices](https://discuss.aerospike.com/t/faq-shadow-device/4900).

The `md5.large` EC2 instance has a 75 GB (69.9 GiB) Local Instance SSD Volume so
the shadow devices need to be _at least_ 69.9 GiB for storage but must also be
sized based on the expected throughput.

An Aerospike `3x` [ACT Test](https://github.com/aerospike/act) will be the basis
for planning the required EBS volume capacity in this example. This test
workload has a large block size of `128 KiB`, an object size of `1.5 KiB`, and
`3000` write requests per second.

A 2x
[write amplication for defrag](https://discuss.aerospike.com/t/faq-why-is-high-water-disk-pct-set-to-50/3054)
will be assumed based on the default values of `50%` for both `defrag-lwm-pct` and `high-water-disk-pct`

#### EBS IOPS

To determine the large write blocks per second of the `3x` ACT workload:

```
WBPS = DEFRAG_AMPLIFICATION × (WRITES_PER_SECOND × RECORD_KIB) ÷ LARGE_BLOCK_KIB
     = 2 × (3000 × 1.5 KiB) ÷ 128 KiB
     = 70.312
```

To determine the EBS IOPS of the `3x` ACT workload:

```
IOPS = CEIL(WBPS × (LARGE_BLOCK_KIB ÷ EBS_IO_KIB))
     = CEIL(70.312 × (128 KiB ÷ 16 KiB))
     = 563
```

The EBS Shadow Device needs to support at least **563 IOPS**. 

To determine IOPS supported by a 69.9 GiB `gp2` EBS Volume:

```
IOPS = CEIL(VOLUME_SIZE_GIB × 3)
     = 209.7
```

*TODO: All math below is way off. I left off here re-calculating based on 16 KiB I/O size.*

A 69.9 GiB EBS volume does not have enough IOPS capacity for a `3x` ACT workload
and is well under the _Max IOPS per Instance_ of 80,000 IOPS.

#### EBS Throughput

To determine the throughput (T) of the `3x` ACT workload:

```
T = IOPS × LARGE_BLOCK_KIB
  = 71 × 128 KiB
  = 9.306 MiB/s
```

The EBS Shadow Device needs to support at least **9.306 MiB/s**.

To determine throughput (T) of a 69.9 GiB `gp2` EBS volume:

```
T = VOLUME_SIZE_GIB × IOPS_PER_GIB × LARGE_BLOCK_SIZE
  = 69.9 × 3 × 128 KiB
  = 27.486 MiB/s
```

Again, the 69.9 GiB Shadow Device has more than enough throughput for a `3x` ACT
workload and is well under the _Max Throughput per Instance_ of 1750 MiB/s.

See [EBS Volume Types](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSVolumeTypes.html)
in the AWS documentation for more details on EBS capacity and limits.

Verifying the EBS throghput with `iostat`:

```
avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.71    0.00    0.15   46.88    0.00   52.26

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
nvme1n1           0.00     0.00 6070.58   70.58 18034.67  9034.67     8.82     0.27    0.18    0.18    0.17   0.04  23.47
```




#### Configure Aerospike

TODO: Ansible