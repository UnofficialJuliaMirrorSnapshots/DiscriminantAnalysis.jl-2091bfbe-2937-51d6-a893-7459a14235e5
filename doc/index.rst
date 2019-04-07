Introduction
============

`DiscriminantAnalysis.jl`_ is a Julia package for multiple linear and quadratic 
regularized discriminant analysis (LDA & QDA respectively). LDA and QDA are
distribution-based classifiers with the underlying assumption that data follows
a multivariate normal distribution. LDA differs from QDA in the assumption about 
the class variability; LDA assumes that all classes share the same within-class 
covariance matrix whereas QDA relaxes that constraint and allows for distinct 
within-class covariance matrices. This results in LDA being a linear classifier
and QDA being a quadratic classifier.

Installation
============

The source code is available on Github:

  * `DiscriminantAnalysis.jl`_

.. _DiscriminantAnalysis.jl: https://github.com/trthatcher/DiscriminantAnalysis.jl

To add the package from Julia:

.. code:: julia

  Pkg.add("DiscriminantAnalysis")

Theory
======

Linear and Quadratic Discriminant Analysis in the context of classification 
arise as simple probabilistic classifiers. Discriminant Analysis works under the
assumption that each class follows a Gaussian distribution. That is, for each
class :math:`k`, the probability distribution can be modelled by:

.. math::
    
    f_k(x) = \frac{\exp\left(\frac{-1}{2}(\mathbf{x}-\mathbf{\mu_k})^{\intercal}\Sigma_k^{-1}(\mathbf{x}-\mathbf{\mu_k})\right)}{(2\pi)^{p/2}\left|\Sigma_k\right|^{1/2}}

Let :math:`\pi_k` represent the prior class membership probabilities. 
Application of Baye's Theorem results in:

.. math::

    P(K = k | X = \mathbf{x}) = \frac{f_k(\mathbf{x})\pi_k}{\sum_i f_i(\mathbf{x})\pi_i}

Noting that probabilities are non-zero and the natural logarithm is
monotonically increasing, the following rule can be used for classification:

.. math::

    \operatorname{arg\,max}_k\frac{f_k(\mathbf{x})\pi_k}{\sum_i f_i(\mathbf{x})\pi_i}
    = \operatorname{arg\,max}_k log(f_k(\mathbf{x})) + log(\pi_k)

Application of the natural logarithm helps to simplify the classification rule 
when working with a Gaussian distribution. The resulting set of functions
:math:`\delta_k` are known as **discriminant functions**. In the context of LDA
and QDA, discriminant functions are of the form:

.. math::

    \delta_k(\mathbf{x}) = log(f_k(\mathbf{x})) + log(\pi_k)


Linear Discriminant Analysis (LDA)
----------------------------------

Linear Discriminant Analysis works under the simplifying assumption that
:math:`\Sigma_k = \Sigma` for each class :math:`k`. In other words, the classes
share a common within-class covariance matrix. Since
:math:`\mathbf{x}^\intercal \Sigma \mathbf{x}` term is constant across classes, 
this simplifies the discriminant function to a linear classifier:

.. math::

    \delta_k(x) =  
    -\mathbf{\mu_k}^{\intercal}\Sigma^{-1}\mathbf{x} +
    \frac{1}{2}\mathbf{\mu_k}\Sigma^{-1}\mathbf{\mu_k}
    + \log(\pi_k)

The following plot shows the linear classification boundaries that result when a
sample data set of two bi-variate Gaussian variables is modelled using linear
discriminant analysis:

.. image:: visualization/lda.png


Quadratic Discriminant Analysis (QDA)
-------------------------------------

Quadratic Discriminant Analysis does not make the simplifying assumption that
each class shares the same covariance matrix. This results in a quadratic
classifier in :math:`\mathbf{x}`:

.. math::

    \delta_k(\mathbf{x}) =  
    -\frac{1}{2}(\mathbf{x}-\mathbf{\mu_k})^{\intercal}\Sigma_k^{-1}(\mathbf{x}-\mathbf{\mu_k})
    -\frac{1}{2}\log\left(\left|\Sigma_k\right|\right) 
    + \log(\pi_k)

The following plot shows the quadratic classification boundaries that result 
when a sample data set of two bi-variate Gaussian variables is modelled using 
quadratic discriminant analysis:


.. image:: visualization/qda.png

Note that quadratic discriminant analysis does not necessarily perform better
than linear discriminant analysis. 


Canonical Discriminant Analysis (CDA)
-------------------------------------

Canonical discriminant analysis expands upon linear discriminant analysis by
noting that the class centroids lie in a :math:`c-1` dimensional subspace of the
:math:`p` dimensions of the data where :math:`c` is the number of classes. 
Defining the between-class covariance matrix:

.. math::

    \Sigma_b = \frac{1}{c} \sum_{k=1}^{c} (\mu_k - \mu)(\mu_k - \mu)^{\intercal}

Canonical discriminant analysis then optimizes the generalized Rayleigh quotient
of the between-class covariance and the within-class covariance to solve for 
the optimal axes to describe class separability:

.. math::

    \operatorname{arg\,max}_{\mathbf{w}}\frac{\mathbf{w}^{\intercal}\Sigma_b\mathbf{w}}{\mathbf{w}^{\intercal}\Sigma\mathbf{w}}

For two class LDA, the canonical coordinate is perpendicular to the separating
hyperplane produced by the decision boundary. For the LDA model above, the
dimensionality is reduced from 2 to 1. The following image shows the resulting
distribution of points relative to the canonical coordinate:

.. image:: visualization/cda.png


Using LDA to do QDA
-------------------

A quadratic boundary using LDA can be generated by squaring each variable and by
producing all the interaction terms. For two variables :math:`x` and :math:`y`,
this is simply:

.. math::

    x + y + x^2 + y^2 + xy

The transformed variables may be used as inputs for the LDA model. This results
in a quadratic decision boundary:

.. image:: visualization/qlda.png

Note that this boundary does not correspond to the same boundary produced by
QDA.

Calculation Method
------------------

As a result of floating point arithmetic, full inversion of a matrix may
introduce numerical error. Even inversion of a small matrix may produce
relatively large error (see `Hilbert matrices`_), so alternative methods are 
used to ensure numerical stability.

For each class covariance matrix in QDA (or the overall covariance matrix in
LDA), a whitening matrix :math:`\mathbf{W}_k` is computed such that:

.. math::

    \operatorname{V}(\mathbf{X}_k \mathbf{W}_k) 
    = \mathbf{W}_k^{\intercal} \operatorname{V}(\mathbf{X}_k) \mathbf{W}_k
    = \mathbf{W}_k^{\intercal} \mathbf{\Sigma}_k \mathbf{W}_k
    = I \quad \implies \quad \mathbf{W} = \mathbf{\Sigma}^{-1/2}

This is accomplished using an QR or singular value decomposition of the data 
matrix where possible. When the covariance matrix must be calculated directly,
the Cholesky decomposition is used to whiten the data instead.

Once the whitening matrix has been computed, we can then use the transformation:

.. math::

    \mathbf{z}_k = \mathbf{W}_k^{\intercal}\mathbf{x}
    \quad \implies \quad \mathbf{Z}_k = \mathbf{X}\mathbf{W}_k

Since we are now working in the transformed space, the determinant goes to zero
and the inverse is simply the identity matrix. This results in the simplified
discriminant function:

.. math::

    \delta_k(\mathbf{z_k}) =  
    -\frac{1}{2}(\mathbf{z_k}-\mathbf{\mu_k})^{\intercal}(\mathbf{z_k}-\mathbf{\mu_k})
    + \log(\pi_k)

.. _Hilbert matrices: https://en.wikipedia.org/wiki/Hilbert_matrix

Package Interface
=================

.. _format notes:

.. note::

    Data matrices may be stored in either row-major or column-major ordering of
    observations. Row-major ordering means each row corresponds to an
    observation and column-major ordering means each column corresponds to an
    observation:

    .. math:: \mathbf{X}_{row} = 
                  \begin{bmatrix} 
                      \leftarrow \mathbf{x}_1 \rightarrow \\ 
                      \leftarrow \mathbf{x}_2 \rightarrow \\ 
                      \vdots \\ 
                      \leftarrow \mathbf{x}_n \rightarrow 
                   \end{bmatrix}
              \qquad
              \mathbf{X}_{col} = 
                  \begin{bmatrix}
                      \uparrow & \uparrow & & \uparrow  \\
                      \mathbf{x}_1 & \mathbf{x}_2 & \cdots & \mathbf{x_n} \\
                      \downarrow & \downarrow & & \downarrow
                  \end{bmatrix}

    In DiscriminantAnalysis.jl, the input data matrix ``X`` is assumed to be 
    stored in the same format as a `design matrix`_ in statistics (row-major) by
    default. This ordering can be switched between row-major and column-major by
    setting the ``order`` argument to ``Val{:row}`` and ``Val{:col}``,
    respectively.

.. _design matrix: https://en.wikipedia.org/wiki/Design_matrix

.. function:: lda(X, y [; order, M, priors, gamma])

    Fit a regularized linear discriminant model based on data ``X`` and class 
    identifier ``y``. ``X`` must be a matrix of floats and ``y`` must be a 
    vector of positive integers that index the classes. ``M`` is an optional 
    matrix of class means. If ``M`` is not supplied, it defaults to point 
    estimates of the class means. The ``priors`` argument represents the prior 
    probability of class membership. If ``priors`` is not supplied, it defaults
    to equal class weights.

    .. note::

        See the `format notes`_ for the data matrix ``X``.
    
    Gamma is a regularization parameter that shrinks the covariance matrix 
    towards the average eigenvalue:

    .. math::

        \mathbf{\Sigma}(\gamma) = (1-\gamma)\mathbf{\Sigma} + \gamma
          \left(\frac{\operatorname{trace}(\mathbf{\Sigma})}{p}\right) \mathbf{I}

    This type of regularization can be used counteract bias in the eigenvalue
    estimates generated from the sample covariance matrix.

    The components of the LDA model may be extracted from the ``ModelLDA`` 
    object returned by the ``lda`` function:

    ========== =====================================================
    Field      Description
    ========== =====================================================
    ``is_cda`` Boolean value; the model is a CDA model if ``true``
    ``W``      The whitening matrix used to decorrelate observations
    ``order``  The ordering of observations in the data matrix
    ``M``      A matrix of class means; one per row
    ``priors`` A vector of class prior probabilities
    ``gamma``  The regularization parameter as defined above.
    ========== =====================================================


.. function:: cda(X, y [; order, M, priors, gamma])

    Fit a regularized canonical discriminant model based on data ``X`` and class 
    identifier ``y``. The CDA model is identical to an LDA model, except that
    dimensionality reduction is included in the whitening transformation matrix.
    See the ``lda`` documentation for information on the arguments.

.. function:: qda(X, y [; order, M, priors, gamma, lambda])

    Fit a regularized quadratic discriminant model based on data ``X`` and class 
    identifier ``y``. ``X`` must be a matrix of floats and ``y`` must be a 
    vector of positive integers that index the classes. ``M`` is an optional 
    matrix of class means. If ``M`` is not supplied, it defaults to point 
    estimates of the class means. The ``priors`` argument represents the prior 
    probability of class membership. If ``priors`` is not supplied, it defaults
    to equal class weights.
    
    .. note::

        See the `format notes`_ for the data matrix ``X``.

    Lambda is a regularization parameter that shrinks the class covariance 
    matrices towards the overall covariance matrix:

    .. math::

        \mathbf{\Sigma}_{k}(\lambda) = (1-\lambda)\mathbf{\Sigma}_k 
         + \lambda \mathbf{\Sigma}

    As in LDA, gamma is a regularization parameter that shrinks the covariance
    matrix towards the average eigenvalue:

    .. math::

        \mathbf{\Sigma}_{k}(\gamma,\lambda) 
        = (1-\gamma)\mathbf{\Sigma}_{k}(\lambda) + \gamma
          \left(\frac{\operatorname{trace}(\mathbf{\Sigma}_{k}(\lambda))}{p}\right) \mathbf{I}
     
    The components of the QDA model may be extracted from the ``ModelQDA`` 
    object returned by the ``qda`` function:

    ========== =====================================================
    Field      Description
    ========== =====================================================
    ``W_k``    The vector of whitening matrices (one per class)
    ``order``  The ordering of observations in the data matrix
    ``M``      A matrix of class means; one per row
    ``priors`` A vector of class prior probabilities
    ``gamma``  The regularization parameter as defined above.
    ``lambda`` The regularization parameter as defined above.
    ========== =====================================================

.. function:: discriminants(model, Z)

    Returns a matrix of discriminant function values based on ``model``. Each
    column of values corresponds to a class discriminant function and each row
    corresponds to the discriminant function values for an observation in ``Z``.
    For example, ``Z[i,j]`` corresponds to the discriminant function value of
    class ``j`` for observation ``i``.

.. function:: classify(model, Z)

    Returns a vector of class indices based on the classification rule. This
    function takes the output of the ``discriminants`` function and applies
    ``indmax`` to each row to determine the class.

References
==========

.. [fried] Friedman J. 1989. *Regularized discriminant analysis.* Journal of
           the American statistical association 84.405; p. 165-175.

.. [hff] Hastie T, Tibshirani R, Friedman J, Franklin J. 2005. *The elements of
         statistical learning: data mining, inference and prediction*. The 
         Mathematical Intelligencer, 27(2); p. 83-85.
