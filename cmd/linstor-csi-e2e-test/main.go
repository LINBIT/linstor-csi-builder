package main

import (
	"encoding/json"
	"encoding/xml"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"testing"

	"github.com/onsi/ginkgo"
	"github.com/onsi/ginkgo/config"
	"github.com/onsi/ginkgo/reporters"
	"github.com/onsi/gomega"
	storagev1 "k8s.io/api/storage/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/util/sets"
	"k8s.io/kubernetes/test/e2e/framework"
	"k8s.io/kubernetes/test/e2e/framework/volume"
	storageframework "k8s.io/kubernetes/test/e2e/storage/framework"
	"k8s.io/kubernetes/test/e2e/storage/testsuites"
	"k8s.io/kubernetes/test/e2e/storage/utils"
)

var (
	linstorStoragePool string
	replicas           int
)

type linstorDriver struct {
}

// Returns the SnapshotClass to use during testing.
func (l linstorDriver) GetSnapshotClass(config *storageframework.PerTestConfig, parameters map[string]string) *unstructured.Unstructured {
	ns := config.Framework.Namespace.Name
	name := fmt.Sprintf("linstor-%s-sc", config.Prefix)

	return utils.GenerateSnapshotClassSpec("linstor.csi.linbit.com", parameters, ns, name)
}

// Returns the StorageClass to use for DynamicPV testing. Most k8s related parameters (fs- vs. block-mode, fs-type, etc...)
// will be set by the test itself, just set the LINSTOR related things.
func (l *linstorDriver) GetDynamicProvisionStorageClass(config *storageframework.PerTestConfig, fsType string) *storagev1.StorageClass {
	ns := config.Framework.Namespace.Name
	name := fmt.Sprintf("linstor-%s-sc", config.Prefix)
	placementPolicy := "AutoPlace"
	if config.Framework.BaseName == "topology" {
		placementPolicy = "FollowTopology"
	}

	params := map[string]string{
		"autoPlace":                 fmt.Sprintf("%d", replicas),
		"storagePool":               linstorStoragePool,
		"resourceGroup":             name,
		"placementPolicy":           placementPolicy,
		"csi.storage.k8s.io/fstype": fsType,
	}

	return storageframework.GetStorageClass("linstor.csi.linbit.com", params, nil, ns)
}

// Get a description of the driver to test.
func (l *linstorDriver) GetDriverInfo() *storageframework.DriverInfo {
	return &storageframework.DriverInfo{
		Name:        "linstor-csi",
		MaxFileSize: storageframework.FileSizeLarge,
		SupportedFsType: sets.NewString(
			"", // Default fsType
			"ext2",
			"ext3",
			"ext4",
			"xfs",
		),
		SupportedSizeRange: volume.SizeRange{
			// The file sizes test does not consider that a small volume can never support larger files
			Min: "2Gi",
		},
		// Random set of mount options we may or may not support
		SupportedMountOption: sets.NewString("noatime", "discard"),
		TopologyKeys: []string{
			"linbit.com/hostname",
		},
		Capabilities: map[storageframework.Capability]bool{
			storageframework.CapPersistence:         true,
			storageframework.CapBlock:               true,
			storageframework.CapFsGroup:             true,
			storageframework.CapExec:                true,
			storageframework.CapSnapshotDataSource:  true,
			storageframework.CapPVCDataSource:       true,
			storageframework.CapMultiPODs:           true,
			storageframework.CapControllerExpansion: true,
			storageframework.CapNodeExpansion:       true,
			storageframework.CapTopology:            true,
			storageframework.CapCapacity:            true,
		},
		StressTestOptions: &storageframework.StressTestOptions{
			NumPods:     10,
			NumRestarts: 10,
		},
		VolumeSnapshotStressTestOptions: &storageframework.VolumeSnapshotStressTestOptions{
			NumPods:      10,
			NumSnapshots: 10,
		},
	}
}

func (l *linstorDriver) SkipUnsupportedTest(pattern storageframework.TestPattern) {}

func (l *linstorDriver) PrepareTest(f *framework.Framework) (*storageframework.PerTestConfig, func()) {
	cfg := &storageframework.PerTestConfig{
		Driver:    l,
		Prefix:    "linstor",
		Framework: f,
	}

	return cfg, func() {}
}

// Ensure our test driver implements the required interfaces.
var (
	_ storageframework.TestDriver              = &linstorDriver{}
	_ storageframework.DynamicPVTestDriver     = &linstorDriver{}
	_ storageframework.SnapshottableTestDriver = &linstorDriver{}
)

// Register our test suite with the ginkgo test runner. Taken from:
// https://github.com/kubernetes/kubernetes/blob/v1.21.1/test/e2e/storage/csi_volumes.go#L35
var _ = utils.SIGDescribe("LINSTOR CSI Volumes", func() {
	driver := &linstorDriver{}
	ginkgo.Context(storageframework.GetDriverNameWithFeatureTags(driver), func() {
		storageframework.DefineTestSuites(driver, append(testsuites.BaseSuites, testsuites.CSISuites...))
	})
})

func main() {
	framework.RegisterCommonFlags(flag.CommandLine)
	framework.RegisterClusterFlags(flag.CommandLine)
	framework.AfterReadingAllFlags(&framework.TestContext)
	flag.StringVar(&linstorStoragePool, "linstor-csi-e2e.storage-pool", "e2epool", "set the LINSTOR storage pool to use for testing")
	flag.IntVar(&replicas, "linstor-csi-e2e.volume-replicas", 2, "set the number of volume replicas LINSTOR should create")
	flag.Parse()

	gomega.RegisterFailHandler(ginkgo.Fail)
	ginkgo.RunSpecs(&testing.T{}, "CSI Suite")

	if config.DefaultReporterConfig.ReportFile != "" {
		xmlReportFile, err := os.Open(config.DefaultReporterConfig.ReportFile)
		if err != nil {
			log.Fatalf("failed to open xml report: %v", err)
		}

		defer xmlReportFile.Close()
		decoder := xml.NewDecoder(xmlReportFile)

		var testsuite reporters.JUnitTestSuite
		err = decoder.Decode(&testsuite)
		if err != nil {
			log.Fatalf("failed to decode xml report: %v", err)
		}

		reportFilenameBase := strings.TrimSuffix(config.DefaultReporterConfig.ReportFile, ".xml")
		jsonReportFile, err := os.Create(reportFilenameBase + ".json")
		if err != nil {
			log.Fatalf("failed to create json report: %v", err)
		}

		defer jsonReportFile.Close()

		encoder := json.NewEncoder(jsonReportFile)
		encoder.SetIndent("", "  ")
		err = encoder.Encode(testsuite)
		if err != nil {
			log.Fatalf("failed to write json report: %v", err)
		}
	}
}
