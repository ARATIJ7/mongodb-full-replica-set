#!/bin/bash

mongo <<EOF
rs.initiate(
  {
    _id : "rs0",
    members: [
      { _id: 0, host: "${ip0}:27017" },
      { _id: 1, host: "${ip1}:27017" },
      { _id: 2, host: "${ip2}:27017" }
    ]
  }
)
EOF
