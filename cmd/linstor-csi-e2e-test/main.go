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
	"k8s.io/kubernetes/test/e2e/storage/testpatterns"
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
func (l linstorDriver) GetSnapshotClass(config *testsuites.PerTestConfig) *unstructured.Unstructured {
	ns := config.Framework.Namespace.Name
	name := fmt.Sprintf("linstor-%s-sc", config.Prefix)

	return testsuites.GetSnapshotClass("linstor.csi.linbit.com", map[string]string{}, ns, name)
}

// Returns the StorageClass to use for DynamicPV testing. Most k8s related parameters (fs- vs. block-mode, fs-type, etc...)
// will be set by the test itself, just set the LINSTOR related things.
func (l linstorDriver) GetDynamicProvisionStorageClass(config *testsuites.PerTestConfig, fsType string) *storagev1.StorageClass {
	ns := config.Framework.Namespace.Name
	name := fmt.Sprintf("linstor-%s-sc", config.Prefix)

	params := map[string]string{
		"autoPlace":                 fmt.Sprintf("%d", replicas),
		"storagePool":               linstorStoragePool,
		"resourceGroup":             name,
		"csi.storage.k8s.io/fstype": fsType,
	}

	return testsuites.GetStorageClass("linstor.csi.linbit.com", params, nil, ns, name)
}

// Get a description of the driver to test.
func (l linstorDriver) GetDriverInfo() *testsuites.DriverInfo {
	return &testsuites.DriverInfo{
		Name:        "linstor-csi",
		MaxFileSize: testpatterns.FileSizeLarge,
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
		Capabilities: map[testsuites.Capability]bool{
			testsuites.CapPersistence:         true,
			testsuites.CapBlock:               true,
			testsuites.CapFsGroup:             true,
			testsuites.CapExec:                true,
			testsuites.CapSnapshotDataSource:  true,
			testsuites.CapPVCDataSource:       true,
			testsuites.CapMultiPODs:           true,
			testsuites.CapControllerExpansion: true,
			testsuites.CapNodeExpansion:       true,
			testsuites.CapTopology:            true,
		},
		StressTestOptions: &testsuites.StressTestOptions{
			NumPods:     10,
			NumRestarts: 10,
		},
	}
}

func (l linstorDriver) SkipUnsupportedTest(pattern testpatterns.TestPattern) {}

func (l linstorDriver) PrepareTest(f *framework.Framework) (*testsuites.PerTestConfig, func()) {
	config := &testsuites.PerTestConfig{
		Driver:    l,
		Prefix:    "linstor",
		Framework: f,
	}

	return config, func() {}
}

// Ensure our test driver implements the required interfaces.
var (
	_ testsuites.TestDriver              = &linstorDriver{}
	_ testsuites.DynamicPVTestDriver     = &linstorDriver{}
	_ testsuites.SnapshottableTestDriver = &linstorDriver{}
)

// Register our test suite with the ginkgo test runner. Taken from:
// https://github.com/kubernetes/kubernetes/blob/v1.19.4/test/e2e/storage/csi_volumes.go#L35
var _ = utils.SIGDescribe("LINSTOR CSI Volumes", func() {
	driver := &linstorDriver{}
	ginkgo.Context(testsuites.GetDriverNameWithFeatureTags(driver), func() {
		testsuites.DefineTestSuite(driver, append(testsuites.BaseSuites, testsuites.CSISuites...))
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
