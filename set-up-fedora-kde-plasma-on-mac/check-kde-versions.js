#!/usr/bin/env node

const https = require("https");

const bodhiPath = "https://src.fedoraproject.org/rpms";
const projects = ["kwin", "kio", "dolphin", "aurorae", "plasma-desktop"];

fetchSpecFile = (project, fedoraVersion) => {
  const url = `${bodhiPath}/${project}/raw/f${fedoraVersion}/f/${project}.spec`;

  return new Promise((resolve, reject) => {
    https
      .get(url, (res) => {
        let dataList = [];
        res.on("data", (chunk) => dataList.push(chunk));
        res.on("end", () => {
          const versionMatch = dataList.join('').match(/^Version:\s*(\S+)/m);

          if (versionMatch) {
            return resolve({ project, version: versionMatch[1] });
          }

          resolve({ project, version: "Not found" });
        });
      })
      .on("error", (err) => reject({ project, version: "Error fetching" }));
  });
};

// Read Fedora version from command line
const [_, __, fedoraVersion] = process.argv;
if (!fedoraVersion) {
  console.error("❗ Please provide a Fedora major version (e.g., 42)");
  process.exit(1);
}

const promises = projects.map((project) =>
  fetchSpecFile(project, fedoraVersion)
);

Promise.all(promises).then((results) => {
  console.log(`📦 Stable versions for Fedora ${fedoraVersion}:`);
  results.forEach(({ project, version }) => {
    console.log(`- ${project}: ${version}`);
  });
});
