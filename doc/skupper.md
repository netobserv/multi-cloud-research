
# Overview

This page summarizes a demonstration of network topology and connectivity between clusters using [Skupper](https://skupper.io/).

We have 2 clusters named **east** and **west**.
In the **east** cluster, we have an application called **productpage**, which uses components **reviews**, **ratings**, and **details**.
The pod and service for **details** sit in the **west** cluster, while the other pods sit in the **east** cluster.

Mbg is used to make the **details** service (on the **west** cluster) available on the **east** cluster.
Skupper creates a proxy **details** service in the **east** cluster.
To create this setup, run the command:
```
```

The topology looks like the following.


![skupper-plain-png](images/skupper-plain.png)

There is network traffic between **skupper-server/east** and **skupper-server/west** that makes **details** service to appear as if it is on **east**.

The traffic between **skupper-server/east** and **skupper-server/west** is not seen in the picture because as far as the console is concerned, this traffic is outside of its purview - it is in the internet where the console does not see the traffic.


To show the virual connectivity between the clusters, we re-assign the **skupper-server** nodes to their own namespace, so that the GUI places them together in the same box, giving the appearance of the continuity of the network flow.
To create this setup, run the command:
```
make all-in-one-skupper-gui
```

The topology now looks like the following.

![skupper-gateway-png](images/skupper-gateway.png)

The **details** pod actually sits in the **west** cluster, but its service is available on the **east** cluster.

Only entities (pods and services) that actually send traffic between each other and produce flow logs are shown in the graphs.
