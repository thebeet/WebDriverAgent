//
//  XCUIDevice+Usage.m
//  WebDriverAgent
//
//  Created by 项光特 on 2017/3/15.
//

#import "XCUIDevice+Usage.h"

#include <sys/sysctl.h>
#include <sys/types.h>
#include <mach/mach.h>
#include <mach/processor_info.h>
#include <mach/mach_host.h>

processor_info_array_t cpuInfo, prevCpuInfo;
mach_msg_type_number_t numCpuInfo, numPrevCpuInfo;
unsigned numCPUs = 2;
NSTimer *updateTimer;
NSLock *CPUUsageLock;

double getCPUUsage()
{
    int mib[2U] = { CTL_HW, HW_NCPU };
    size_t sizeOfNumCPUs = sizeof(numCPUs);
    int status = sysctl(mib, 2U, &numCPUs, &sizeOfNumCPUs, NULL, 0U);
    if(status)
        numCPUs = 1;
    natural_t numCPUsU = 0U;
    kern_return_t err = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUsU, &cpuInfo, &numCpuInfo);
    if(err == KERN_SUCCESS) {
        [CPUUsageLock lock];
        float all = 0.0;
        for(unsigned i = 0U; i < numCPUs; ++i) {
            float inUse, total;
            if(prevCpuInfo) {
                inUse = (
                         (cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_USER]   - prevCpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_USER])
                         + (cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_SYSTEM] - prevCpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_SYSTEM])
                         + (cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_NICE]   - prevCpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_NICE])
                         );
                total = inUse + (cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_IDLE] - prevCpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_IDLE]);
            } else {
                inUse = cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_USER] + cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_SYSTEM] + cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_NICE];
                total = inUse + cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_IDLE];
            }
            all = (all * i + inUse / total) / (i + 1);
            NSLog(@"Core: %u Usage: %f",i,inUse / total);
        }
        [CPUUsageLock unlock];
        
        if(prevCpuInfo) {
            size_t prevCpuInfoSize = sizeof(integer_t) * numPrevCpuInfo;
            vm_deallocate(mach_task_self(), (vm_address_t)prevCpuInfo, prevCpuInfoSize);
        }
        
        prevCpuInfo = cpuInfo;
        numPrevCpuInfo = numCpuInfo;
        
        cpuInfo = NULL;
        numCpuInfo = 0U;
        return all;
    } else {
        NSLog(@"Error!");
        return 0.0;
    }
}

NSDictionary *freeMemory(void) {
    mach_port_t host_port = mach_host_self();
    mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    vm_size_t pagesize;
    vm_statistics_data_t vm_stat;
    
    host_page_size(host_port, &pagesize);
    (void) host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size);
    NSProcessInfo *info = [NSProcessInfo processInfo];
    NSDictionary *result = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithDouble:(vm_stat.free_count * pagesize / 1000.0)], @"free",
                            [NSNumber numberWithDouble:(vm_stat.active_count * pagesize / 1000.0)], @"active",
                            [NSNumber numberWithDouble:(vm_stat.wire_count * pagesize / 1000.0)], @"wire_count",
                            [NSNumber numberWithDouble:(vm_stat.inactive_count * pagesize / 1000.0)], @"inactive",
                            [NSNumber numberWithDouble:(vm_stat.purgeable_count * pagesize / 1000.0)], @"purgeable_count",
                            [NSNumber numberWithDouble:(info.physicalMemory / 1000.0)], @"total",
                            nil];
    NSLog(@"%f", (vm_stat.active_count + vm_stat.wire_count + vm_stat.inactive_count
                  + vm_stat.purgeable_count + vm_stat.free_count + vm_stat.reactivations) * pagesize / 1000.0);
    
    return result;
}




@implementation XCUIDevice (Usage)

- (double)CPUUsage {
    return getCPUUsage();
}

- (NSDictionary *)MemoryUsage {
    return freeMemory();
}

- (double)BatteryUsage {
    UIDevice.currentDevice.batteryMonitoringEnabled = true;
    float batteryLevel = [UIDevice currentDevice].batteryLevel;
    NSLog(@"%f",batteryLevel);
    return (double)batteryLevel;
}


@end
