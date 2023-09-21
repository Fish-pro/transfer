```
// CreateV1beta1IngressForCloudshell create ingress for cloudshell, if there isn't an ingress controller server
// in the cluster, the ingress is still not working. before create ingress, there's must a service
// as the ingress backend service. all of services should be loaded in an ingress "cloudshell-ingress".
func (c *CloudShellReconciler) CreateV1beta1IngressForCloudshell(ctx context.Context, service *corev1.Service, cloudshell *cloudshellv1alpha1.CloudShell) error {
	ingress := &extensionsv1beta1.Ingress{}
	objectKey := IngressNamespacedName(cloudshell)
	err := c.Get(ctx, objectKey, ingress)
	if err != nil && !apierrors.IsNotFound(err) {
		return err
	}

	// if there is not ingress in the cluster, create the base ingress.
	if ingress != nil && apierrors.IsNotFound(err) {
		var ingressClassName string
		if cloudshell.Spec.IngressConfig != nil && len(cloudshell.Spec.IngressConfig.IngressClassName) > 0 {
			ingressClassName = cloudshell.Spec.IngressConfig.IngressClassName
		}

		// set default path prefix.
		rulePath := SetRouteRulePath(cloudshell)
		ingressTemplateValue := helper.NewIngressTemplateValue(objectKey, ingressClassName, service.Name, rulePath)
		ingressBytes, err := util.ParseTemplate(manifests.IngressTmplV1beta1, ingressTemplateValue)

		if err != nil {
			return errors.Wrap(err, "failed to parse cloudshell ingress manifest")
		}

		decoder := scheme.Codecs.UniversalDeserializer()
		obj, _, err := decoder.Decode(ingressBytes, nil, nil)
		if err != nil {
			klog.ErrorS(err, "failed to decode ingress manifest", "cloudshell", klog.KObj(cloudshell))
			return err
		}
		ingress = obj.(*extensionsv1beta1.Ingress)
		ingress.SetLabels(map[string]string{constants.CloudshellOwnerLabelKey: cloudshell.Name})

		return c.Create(ctx, ingress)
	}

	// there is an ingress in the cluster, add a rule to the ingress.
	IngressRule := ingress.Spec.Rules[0].IngressRuleValue.HTTP
	pathType := extensionsv1beta1.PathTypePrefix
	IngressRule.Paths = append(IngressRule.Paths, extensionsv1beta1.HTTPIngressPath{
		PathType: &pathType,
		Path:     SetRouteRulePath(cloudshell),
		Backend: extensionsv1beta1.IngressBackend{
			ServiceName: service.Name,
			ServicePort: intstr.FromInt(7681),
		},
	})
	// TODO: All paths will be rewritten here
	ans := ingress.GetAnnotations()
	if ans == nil {
		ans = make(map[string]string)
	}
	ans["nginx.ingress.kubernetes.io/rewrite-target"] = "/"
	ingress.SetAnnotations(ans)
	return c.Update(ctx, ingress)
}

```

```
		if apierrors.IsNotFound(err) {
			if err := c.CreateIngressForCloudshell(ctx, service, cloudshell); err != nil {
				klog.ErrorS(err, "failed create ingress for cloudshell", "cloudshell", klog.KObj(cloudshell))
				return err
			}
		} else {
			if err := c.CreateV1beta1IngressForCloudshell(ctx, service, cloudshell); err != nil {
				klog.ErrorS(err, "failed create v1beta1 ingress for cloudshell", "cloudshell", klog.KObj(cloudshell))
				return err
			}
		}
```

```
	IngressTmplV1beta1 = `
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: {{ .Name }}
  namespace: {{ .Namespace }}
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: {{ .IngressClassName }}
  rules:
  - http:
      paths:
      - path: {{ .Path }}
        backend:
          serviceName: {{ .ServiceName }}
          servicePort: 7681
`
```

